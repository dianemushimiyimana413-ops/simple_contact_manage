const request = require('supertest');

// Mock mysql2 createConnection to avoid needing a real DB for unit tests
jest.mock('mysql2', () => ({
  createConnection: jest.fn(() => ({
    query: (sql, params, cb) => {
      // simple behavior for SELECT * FROM contacts
      if (sql && sql.toString().toLowerCase().includes('select')) {
        return cb(null, [{ id: 1, name: 'Unit Test', phone: '000', email: 'unit@test' }]);
      }
      // for other queries, simulate success
      return cb(null, { insertId: 1 });
    }
  }))
}));

const { app } = require('../../index');

describe('Unit tests - contacts routes (mocked DB)', () => {
  test('GET /contacts returns array', async () => {
    const res = await request(app).get('/contacts');
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
    expect(res.body[0]).toHaveProperty('name', 'Unit Test');
  });

  test('POST /contacts creates contact', async () => {
    const res = await request(app)
      .post('/contacts')
      .send({ name: 'New', phone: '111', email: 'new@test' })
      .set('Content-Type', 'application/json');
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('id');
  });
});
