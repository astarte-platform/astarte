const path = require('path');
const common = require('./webpack.common.js');
const merge = require('webpack-merge');

const entryPath = path.join(__dirname, 'src/static/index.js');

module.exports = merge(common, {
    mode: 'development',
    entry: [
        'webpack-dev-server/client?http://localhost:8080',
        entryPath
    ],
    devServer: {
        // serve index.html in place of 404 responses
        historyApiFallback: true,
        contentBase: './src',
        hot: true
    },
    module: {
        rules: [{
            test: /\.elm$/,
            exclude: [/elm-stuff/, /node_modules/],
            use: [
                {
                    loader: 'elm-assets-loader',
                    options: {
                        module: 'Assets',
                        tagger: 'AssetPath'
                    }
                },
                {
                    loader: 'elm-webpack-loader',
                    options: {
                        verbose: true,
                        warn: true,
                        debug: true
                    }
                }
            ]
        }
        ,{
            test: /\.sc?ss$/,
            use:
                ['style-loader'
                , { loader: 'css-loader'
                  , options: { importLoaders: 1 }
                  }
                , { loader: 'postcss-loader'
                  , options:
                    { config:
                        { path: './' }
                    }
                  }
                , 'sass-loader'
                ]
        }]
    }
});
