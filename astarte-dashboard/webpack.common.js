const path = require('path');
const webpack = require('webpack');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const autoprefixer = require('autoprefixer');

const ASSET_PATH = process.env.ASSET_PATH || '/';

const outputPath = path.join(__dirname, 'dist');
const outputFilename = '[name]-[hash].js';


module.exports = {
    output: {
        path: outputPath,
        filename: `static/js/${outputFilename}`,
        publicPath: ASSET_PATH
    },
    resolve: {
        extensions: ['.js', '.elm'],
        modules: ['node_modules']
    },
    module: {
        //noParse: /\.elm$/,
        rules: [{
            test: /\.(eot|ttf|woff|woff2|svg)$/,
            use: [
                {
                    loader: 'file-loader',
                    options:
                    {
                        name (file) {
                            return '[name]-[hash].[ext]';
                        },
                        context: ''
                    }
                }
            ]
        }]
    },
    plugins: [
        // This makes it possible for us to safely use env vars on our code
        new webpack.DefinePlugin({
            'process.env.ASSET_PATH': JSON.stringify(ASSET_PATH)
        }),
        new webpack.LoaderOptionsPlugin({
            options: {
                postcss: [autoprefixer()]
            }
        }),
        new HtmlWebpackPlugin({
            template: 'src/static/index.html',
            inject: 'body',
            filename: 'index.html'
        })
    ]
}
