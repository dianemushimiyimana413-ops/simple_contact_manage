const { initDb } = require('../index');

initDb(err => {
  if (err) {
    console.error('initDb failed:', err && (err.message || err));
    // non-zero exit to indicate failure
    process.exit(1);
  }
  console.log('initDb: success');
  process.exit(0);
});
