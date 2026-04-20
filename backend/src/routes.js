const express=require('express');const router=express.Router();
const db=require('./db');const {calculateMetrics}=require('./calculations');

// POST /api/measurements - Create new measurement
router.post('/measurements',async(req,res)=>{
  try{
    const {weightKg,heightCm,age,sex,activity,measurementDate}=req.body;
    
    // Validation
    if (!weightKg || !heightCm || !age || !sex) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    if (weightKg <= 0 || heightCm <= 0 || age <= 0) {
      return res.status(400).json({ error: 'Invalid values: must be positive numbers' });
    }
    
    const m=calculateMetrics({weightKg,heightCm,age,sex,activity});
    const date = measurementDate || new Date().toISOString().split('T')[0];
    const q=`INSERT INTO measurements (weight_kg,height_cm,age,sex,activity_level,bmi,bmi_category,bmr,daily_calories,measurement_date,created_at)
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,now()) RETURNING *`;
    const v=[weightKg,heightCm,age,sex,activity,m.bmi,m.bmiCategory,m.bmr,m.dailyCalories,date];
    const r=await db.query(q,v);
    res.status(201).json({measurement:r.rows[0]});
  }catch(e){
    console.error('Error creating measurement:', e);
    res.status(500).json({error: e.message || 'Failed to create measurement'});
  }
});

// GET /api/measurements - Get all measurements
router.get('/measurements',async(req,res)=>{
  try {
    const r=await db.query('SELECT * FROM measurements ORDER BY measurement_date DESC, created_at DESC');
    res.json({rows:r.rows});
  } catch(e) {
    console.error('Error fetching measurements:', e);
    res.status(500).json({error: 'Failed to fetch measurements'});
  }
});

// GET /api/measurements/trends - Get 30-day BMI and weight trends
router.get('/measurements/trends',async(req,res)=>{
  try {
    const q=`SELECT measurement_date AS day, AVG(bmi) AS avg_bmi, AVG(weight_kg) AS avg_weight
    FROM measurements
    WHERE measurement_date >= CURRENT_DATE - interval '30 days' 
    GROUP BY measurement_date 
    ORDER BY measurement_date`;
    const r=await db.query(q);
    res.json({rows:r.rows});
  } catch(e) {
    console.error('Error fetching trends:', e);
    res.status(500).json({error: 'Failed to fetch trends'});
  }
});

// GET /api/profile - Get user profile
router.get('/profile', async (req, res) => {
  try {
    const r = await db.query('SELECT * FROM user_profile WHERE id = 1');
    res.json({ profile: r.rows[0] || null });
  } catch (e) {
    console.error('Error fetching profile:', e);
    res.status(500).json({ error: 'Failed to fetch profile' });
  }
});

// PUT /api/profile - Create or update user profile (singleton)
router.put('/profile', async (req, res) => {
  try {
    const { name, heightCm, age, sex, activity } = req.body;
    if (!heightCm || !age || !sex || !activity) {
      return res.status(400).json({ error: 'Missing required fields: heightCm, age, sex, activity' });
    }
    if (heightCm <= 0 || heightCm >= 300) {
      return res.status(400).json({ error: 'Invalid height: must be between 1 and 299 cm' });
    }
    if (age <= 0 || age >= 150) {
      return res.status(400).json({ error: 'Invalid age: must be between 1 and 149' });
    }
    if (!['male', 'female'].includes(sex)) {
      return res.status(400).json({ error: 'Invalid sex: must be male or female' });
    }
    if (!['sedentary', 'light', 'moderate', 'active', 'very_active'].includes(activity)) {
      return res.status(400).json({ error: 'Invalid activity level' });
    }
    const q = `INSERT INTO user_profile (id, name, height_cm, age, sex, activity_level, updated_at)
      VALUES (1, $1, $2, $3, $4, $5, now())
      ON CONFLICT (id) DO UPDATE SET
        name = EXCLUDED.name,
        height_cm = EXCLUDED.height_cm,
        age = EXCLUDED.age,
        sex = EXCLUDED.sex,
        activity_level = EXCLUDED.activity_level,
        updated_at = now()
      RETURNING *`;
    const v = [name || null, heightCm, age, sex, activity];
    const r = await db.query(q, v);
    res.json({ profile: r.rows[0] });
  } catch (e) {
    console.error('Error saving profile:', e);
    res.status(500).json({ error: 'Failed to save profile' });
  }
});

module.exports=router;