import React, { useEffect, useState } from 'react';
import MeasurementForm from './components/MeasurementForm';
import TrendChart from './components/TrendChart';
import ProfileForm from './components/ProfileForm';
import api, { getProfile } from './api';

export default function App() {
  const [rows, setRows] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [profile, setProfile] = useState(null);
  const [profileLoading, setProfileLoading] = useState(true);
  const [showEditProfile, setShowEditProfile] = useState(false);

  const loadProfile = async () => {
    try {
      const r = await getProfile();
      setProfile(r.data.profile || null);
    } catch (err) {
      console.error('Failed to load profile:', err);
      setProfile(null);
    } finally {
      setProfileLoading(false);
    }
  };

  const load = async () => {
    setLoading(true);
    setError(null);
    try {
      const r = await api.get('/measurements');
      setRows(r.data.rows);
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to load measurements');
    } finally {
      setLoading(false);
    }
  };
  
  useEffect(() => {
    loadProfile();
    load();
  }, []);

  const handleProfileSaved = () => {
    loadProfile();
    setShowEditProfile(false);
  };

  // Calculate stats
  const latestMeasurement = rows[0];
  const totalMeasurements = rows.length;

  const defaultValues = profile ? {
    heightCm: parseFloat(profile.height_cm),
    age: profile.age,
    sex: profile.sex,
    activity: profile.activity_level,
  } : null;
  
  return (
    <>
      <header className="app-header">
        <div className="header-inner">
          <div className="header-brand">
            <div className="header-logo">HT</div>
            <div>
              <h1>Health<span>Tracker</span></h1>
              <p className="app-subtitle">
                {profile?.name ? `Welcome back, ${profile.name}` : 'Your personal health monitoring dashboard'}
              </p>
            </div>
          </div>
        </div>
      </header>

      <div className="page-hero">
        <h2>Track. Measure. Improve.</h2>
        <p>Log your weight daily, monitor your BMI trends, and stay on top of your health goals.</p>
      </div>

      <div className="container">
        {/* Profile Card */}
        <div className="card">
          <div className="card-header">
            <h2>👤 My Profile</h2>
            {profile && !showEditProfile && (
              <button onClick={() => setShowEditProfile(true)}>
                Edit Profile
              </button>
            )}
          </div>
          {profileLoading ? (
            <div className="loading">Loading profile</div>
          ) : profile && !showEditProfile ? (
            <div className="card-body" style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap', alignItems: 'center' }}>
              <span className="measurement-badge badge-bmi">{profile.height_cm} cm</span>
              <span className="measurement-badge badge-bmr">{profile.age} yrs</span>
              <span className="measurement-badge badge-calories">{profile.sex}</span>
              <span className="measurement-badge badge-bmi">{profile.activity_level}</span>
            </div>
          ) : (
            <>
              {!profile && (
                <div className="alert alert-error" style={{ margin: '1.5rem 1.5rem 0' }}>
                  Complete your profile first to start logging measurements.
                </div>
              )}
              <div className="card-body">
                <ProfileForm profile={profile} onSaved={handleProfileSaved} />
                {showEditProfile && (
                  <button
                    onClick={() => setShowEditProfile(false)}
                    style={{ marginTop: '0.75rem' }}
                  >
                    Cancel
                  </button>
                )}
              </div>
            </>
          )}
        </div>

        {/* Add Measurement Card */}
        <div className="card">
          <div className="card-header">
            <h2>⚖️ Log Measurement</h2>
          </div>
          <MeasurementForm onSaved={load} defaultValues={defaultValues} disabled={!profile} />
        </div>

        {/* Stats Cards */}
        {latestMeasurement && (
          <div className="stats-grid">
            <div className="stat-card">
              <span className="stat-label">Current BMI</span>
              <span className="stat-value">{latestMeasurement.bmi}</span>
            </div>
            <div className="stat-card">
              <span className="stat-label">BMR (cal)</span>
              <span className="stat-value">{latestMeasurement.bmr}</span>
            </div>
            <div className="stat-card">
              <span className="stat-label">Daily Calories</span>
              <span className="stat-value">{latestMeasurement.daily_calories}</span>
            </div>
            <div className="stat-card">
              <span className="stat-label">Total Records</span>
              <span className="stat-value">{totalMeasurements}</span>
            </div>
          </div>
        )}

        {/* Recent Measurements Card */}
        <div className="card">
          <div className="card-header">
            <h2>📋 Recent Measurements</h2>
          </div>
          {error && <div className="alert alert-error" style={{ margin: '1rem 1.5rem 0' }}>{error}</div>}
          {loading ? (
            <div className="loading">Loading your data</div>
          ) : (
            <ul className="measurements-list">
              {rows.length === 0 ? (
                <div className="empty-state">
                  <p>No measurements yet. Add your first one above!</p>
                </div>
              ) : (
                rows.slice(0, 10).map(r => (
                  <li key={r.id} className="measurement-item">
                    <span className="measurement-date">
                      {new Date(r.measurement_date || r.created_at).toLocaleDateString('en-US', { 
                        month: 'short', 
                        day: 'numeric', 
                        year: 'numeric' 
                      })}
                    </span>
                    <div className="measurement-data">
                      <span className="measurement-badge badge-bmi">
                        BMI: <strong>{r.bmi}</strong> ({r.bmi_category})
                      </span>
                      <span className="measurement-badge badge-bmr">
                        BMR: <strong>{r.bmr}</strong> cal
                      </span>
                      <span className="measurement-badge badge-calories">
                        Daily: <strong>{r.daily_calories}</strong> cal
                      </span>
                    </div>
                  </li>
                ))
              )}
            </ul>
          )}
        </div>

        {/* Trend Chart Card */}
        <div className="card">
          <div className="card-header">
            <h2>📈 30-Day BMI & Weight Trend</h2>
          </div>
          <div className="chart-container">
            <TrendChart />
          </div>
        </div>
      </div>
    </>
  );
}