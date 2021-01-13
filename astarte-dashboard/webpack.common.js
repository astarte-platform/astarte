const path = require('path');
const webpack = require('webpack');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const Autoprefixer = require('autoprefixer');

module.exports = {
  output: {
    path: path.resolve(__dirname, 'dist/'),
    filename: 'static/js/[name]-[hash].js',
    publicPath: '/',
  },
  resolve: {
    extensions: ['.ts', '.tsx', '.js', '.jsx', '.elm', '.scss'],
    modules: [path.resolve(__dirname, 'src'), 'node_modules'],
    alias: {
      'astarte-client': path.resolve(__dirname, 'src/astarte-client/'),
      'astarte-charts': path.resolve(__dirname, 'src/astarte-charts/'),
      'astarte-charts/react': path.resolve(__dirname, 'src/astarte-charts/react/'),
    },
  },
  module: {
    rules: [
      {
        test: /\.(ts|js)x?$/,
        exclude: /node_modules/,
        loader: 'babel-loader',
      },
      {
        test: [/\.ttf$/, /\.woff2?$/, /\.eot$/, /\.svg$/],
        use: [
          {
            loader: 'file-loader',
            options: {
              name: '[name]-[hash].[ext]',
            },
          },
        ],
      },
    ],
  },
  plugins: [
    Autoprefixer,
    new HtmlWebpackPlugin({
      template: 'src/static/index.html',
      inject: 'body',
      filename: 'index.html',
    }),
  ],
  node: {
    console: true,
    fs: 'empty',
    net: 'empty',
    tls: 'empty',
  },
};
