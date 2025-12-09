const request = require('supertest');
const { app, setDb } = require('../../index');

describe('Unit tests - contacts routes (mocked DB)', () => {
    let mockDb;

    beforeEach(() => {
        // Create a mock DB object with query method
        mockDb = {
            query: jest.fn((sql, params, callback) => {
                // Mock responses based on SQL query type
                if (sql.includes('SELECT *')) {
                    callback(null, [{ id: 1, name: 'Unit Test', phone: '555-1234', email: 'test@example.com' }]);
                } else if (sql.includes('INSERT')) {
                    callback(null, { insertId: 1 });
                } else if (sql.includes('UPDATE')) {
                    callback(null, {});
                } else if (sql.includes('DELETE')) {
                    callback(null, {});
                } else {
                    callback(null, []);
                }
            })
        };
        
        // Inject the mock DB into the app
        setDb(mockDb);
    });

    test('GET /contacts returns array', async () => {
        const res = await request(app).get('/contacts');
        expect(res.statusCode).toBe(200);
        expect(Array.isArray(res.body)).toBe(true);
        expect(res.body[0]).toHaveProperty('name', 'Unit Test');
    });

    test('POST /contacts creates a contact', async () => {
        const res = await request(app)
            .post('/contacts')
            .send({ name: 'John', phone: '555-5678', email: 'john@example.com' });
        expect(res.statusCode).toBe(200);
        expect(res.body).toHaveProperty('id');
    });
});
