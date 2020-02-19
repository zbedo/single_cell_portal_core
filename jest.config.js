module.exports = {
  verbose: true,
  transform: {
    "^.+\\.jsx?$": "babel-jest"
  },
  setupFilesAfterEnv: ['./test/js/setup-tests.js'],
  testPathIgnorePatterns: [
    "config/webpack/test.js"
  ],
  moduleDirectories: [
    'app/javascript',
    'app/assets',
    'node_modules'
  ]
};
