process.env.NODE_ENV = process.env.NODE_ENV || 'development'

const environment = require('./environment')

process.env.BARD_DOMAIN = ''

module.exports = environment.toWebpackConfig()
