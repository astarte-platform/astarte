const path = require('path');
const common = require('./webpack.common.js');
const { merge } = require('webpack-merge');
const webpack = require('webpack');
const CopyWebpackPlugin = require('copy-webpack-plugin');

const TerserPlugin = require('terser-webpack-plugin');
const MiniCssExtractPlugin = require('mini-css-extract-plugin');

const entryPath = path.join(__dirname, 'src/static/index.tsx');

module.exports = merge(common, {
  mode: 'production',
  entry: entryPath,
  module: {
    rules: [
      {
        test: /\.s?css$/,
        use: [
          MiniCssExtractPlugin.loader,
          { loader: 'css-loader', options: { importLoaders: 1 } },
          'postcss-loader',
          'sass-loader',
        ],
      },
    ],
  },
  optimization: {
    minimize: true,
    minimizer: [new TerserPlugin()],
  },
  plugins: [
    new CopyWebpackPlugin({
      patterns: [
        {
          from: 'src/static/img/',
          to: 'static/img/',
        },
        {
          from: 'src/favicon.ico',
        },
      ],
    }),
    new MiniCssExtractPlugin({
      filename: '[name]-[hash].css',
      chunkFilename: '[id].css',
    }),
  ],
});
