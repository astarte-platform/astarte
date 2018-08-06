const path = require('path');
const common = require('./webpack.common.js');
const merge = require('webpack-merge');
const ExtractTextPlugin = require('extract-text-webpack-plugin');
const webpack = require('webpack');
const CopyWebpackPlugin = require('copy-webpack-plugin');

const UglifyJsPlugin = require("uglifyjs-webpack-plugin");
const MiniCssExtractPlugin = require("mini-css-extract-plugin");
const OptimizeCSSAssetsPlugin = require("optimize-css-assets-webpack-plugin");

const entryPath = path.join(__dirname, 'src/static/index.js');

module.exports = merge(common, {
    mode: 'production',
    entry: entryPath,
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
                'elm-webpack-loader'
            ]
        }, {
            test: /\.sc?ss$/,
            use: ExtractTextPlugin.extract({
                fallback: 'style-loader',
                use:
                    [ 'css-loader'
                    , {
                        loader: 'postcss-loader',
                        options: {
                            config: {
                                path: './'
                            }
                        }
                    }
                    , 'sass-loader'
                    ]
            })
        }]
    },
    optimization: {
        minimizer: [
            new UglifyJsPlugin({
                cache: true,
                parallel: true,
                sourceMap: false
            }),
            new OptimizeCSSAssetsPlugin({})
        ]
    },
    plugins: [
        new ExtractTextPlugin({
            filename: 'static/css/[name]-[hash].css',
            allChunks: true,
        }),
        new CopyWebpackPlugin([{
            from: 'src/static/img/',
            to: 'static/img/'
        }, {
            from: 'src/favicon.ico'
        }]),
        new MiniCssExtractPlugin({
            filename: "[name].css",
            chunkFilename: "[id].css"
        })
    ]
});
