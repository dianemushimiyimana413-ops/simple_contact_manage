const request = require('supertest');
const { app, setDb, closeDb, closeServer } = require('../../index');

describe('Integration tests - contacts (mock DB)', () => {
  jest.setTimeout(10000);

  beforeAll(() => {
    // Inject mock DB immediately; skip initDb to avoid real connection attempts
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

  test('GET /contacts responds with 200 and array', (done) => {
    request(app)
      .get('/contacts')
      .expect(200)
      .expect((res) => {
        if (!Array.isArray(res.body)) throw new Error('Response body is not an array');
      })
      .end(done);
  });

  test('GET /contacts/search/:query responds with 200 and array', (done) => {
    request(app)
      .get('/contacts/search/test')
      .expect(200)
      .expect((res) => {
        if (!Array.isArray(res.body)) throw new Error('Response body is not an array');
      })
      .end(done);
  });
});
