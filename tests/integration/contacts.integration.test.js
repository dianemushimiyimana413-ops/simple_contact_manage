const request = require('supertest');
const mysql = require('mysql2/promise');

const { app } = require('../../index');

// Poll helper to wait for DB readiness via the /health endpoint
async function waitForHealthy(retries = 20, delay = 1000) {
  for (let i = 0; i < retries; i++) {
    try {
      const res = await request(app).get('/health');
      if (res.status === 200) return true;
    } catch (e) {
      // ignore
    }
    await new Promise(r => setTimeout(r, delay));
  }
  throw new Error('Service did not become healthy in time');
}

describe('Integration tests - contacts (real DB)', () => {
  beforeAll(async () => {
    // ensure DB host/credentials are available via env
    const host = process.env.DB_HOST || 'localhost';
    const user = process.env.DB_USER || 'root';
    const password = process.env.DB_PASSWORD || 'password';
    const database = process.env.DB_NAME || 'contacts_db';

    // Wait until app health returns healthy (with DB connected)
    await waitForHealthy(30, 2000);

    // Optionally verify we can connect directly with mysql2
    const conn = await mysql.createConnection({ host, user, password, database });
    await conn.end();
  }, 120000);

  test('GET /contacts responds with array', async () => {
    const res = await request(app).get('/contacts');
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test('Search endpoint returns results or empty array', async () => {
    const res = await request(app).get('/contacts/search/john');
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });
});
