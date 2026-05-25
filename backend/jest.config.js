module.exports = {
  testEnvironment: 'node',
  testMatch: ['**/tests/**/*.test.js'],
  collectCoverage: false,
  collectCoverageFrom: [
    'src/**/*.js',
    '!src/app.js',
    '!src/index.js',
    '!src/config/**',
    '!src/db/**',
    '!src/**/*.controller.js',
    '!src/**/*.routes.js',
    '!src/**/*.test.js'
  ],
  coverageThreshold: {
    global: {
      branches:   75,
      functions:  75,
      lines:      75,
      statements: 75
    }
  },
  coverageReporters: ['text', 'html', 'json-summary'],
  coverageDirectory: 'coverage',
  verbose: true,
  forceExit: true
};
