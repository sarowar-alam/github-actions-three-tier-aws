import React, { useState } from 'react';
import { updateProfile } from '../api';

export default function ProfileForm({ profile, onSaved }) {
  const [f, setF] = useState({
    name: profile?.name || '',
    heightCm: profile?.height_cm || '',
    age: profile?.age || '',
    sex: profile?.sex || 'male',
    activity: profile?.activity_level || 'moderate',
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [success, setSuccess] = useState(false);

  const submit = async e => {
    e.preventDefault();
    setError(null);
    setSuccess(false);
    setLoading(true);
    try {
      await updateProfile(f);
      setSuccess(true);
      setTimeout(() => setSuccess(false), 3000);
      onSaved && onSaved();
    } catch (err) {
      setError(err.response?.data?.error || 'Failed to save profile');
    } finally {
      setLoading(false);
    }
  };

  return (
    <form onSubmit={submit}>
      {error && <div className="alert alert-error">{error}</div>}
      {success && <div className="alert alert-success">Profile saved!</div>}

      <div className="form-row">
        <div className="form-group">
          <label htmlFor="profileName">Name (optional)</label>
          <input
            id="profileName"
            type="text"
            value={f.name}
            onChange={e => setF({ ...f, name: e.target.value })}
            placeholder="Your name"
            maxLength={100}
          />
        </div>
      </div>

      <div className="form-row">
        <div className="form-group">
          <label htmlFor="profileHeight">Height (cm)</label>
          <input
            id="profileHeight"
            type="number"
            value={f.heightCm}
            onChange={e => setF({ ...f, heightCm: +e.target.value })}
            required
            min="1"
            max="299"
            step="0.1"
            placeholder="175"
          />
        </div>

        <div className="form-group">
          <label htmlFor="profileAge">Age (years)</label>
          <input
            id="profileAge"
            type="number"
            value={f.age}
            onChange={e => setF({ ...f, age: +e.target.value })}
            required
            min="1"
            max="149"
            placeholder="30"
          />
        </div>
      </div>

      <div className="form-row">
        <div className="form-group">
          <label htmlFor="profileSex">Biological Sex</label>
          <select
            id="profileSex"
            value={f.sex}
            onChange={e => setF({ ...f, sex: e.target.value })}
            required
          >
            <option value="male">Male</option>
            <option value="female">Female</option>
          </select>
        </div>

        <div className="form-group">
          <label htmlFor="profileActivity">Activity Level</label>
          <select
            id="profileActivity"
            value={f.activity}
            onChange={e => setF({ ...f, activity: e.target.value })}
            required
          >
            <option value="sedentary">Sedentary (Little/No Exercise)</option>
            <option value="light">Light (1-3 days/week)</option>
            <option value="moderate">Moderate (3-5 days/week)</option>
            <option value="active">Active (6-7 days/week)</option>
            <option value="very_active">Very Active (2x per day)</option>
          </select>
        </div>
      </div>

      <button type="submit" disabled={loading}>
        {loading ? 'Saving...' : 'Save Profile'}
      </button>
    </form>
  );
}
