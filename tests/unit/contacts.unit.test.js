const request = require('supertest');
const { app, setDb, closeDb, closeServer } = require('../../index');

describe('Unit tests - contacts routes (mocked DB)', () => {
  beforeAll(() => {
    // Immediate mock DB injection to avoid real connections during unit tests
    const mockDb = {
      query: (sql, params, cb) => {
        if (typeof params === 'function') {
          cb = params;
          params = [];
        }
        if (/^\s*SELECT/i.test(sql)) return cb && cb(null, []);
        if (/^\s*INSERT/i.test(sql)) return cb && cb(null, { insertId: 1 });
        return cb && cb(null, {});
      }
    };
    setDb(mockDb);
  });

  afterAll((done) => {
    closeDb(() => closeServer(done));
  });

  test('GET /contacts returns array', async () => {
    const res = await request(app).get('/contacts');
    expect(res.statusCode).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });

  test('POST /contacts inserts and returns id', async () => {
    const payload = { name: 'A', phone: '1', email: 'a@example.com' };
    const res = await request(app).post('/contacts').send(payload);
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('id');
  });
});
