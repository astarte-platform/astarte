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
    fallback: {
      assert: false,
      crypto: require.resolve("crypto-browserify"),
      stream: require.resolve("stream-browserify"),
      util: require.resolve("util/"),
    },
    alias: {
      "astarte-client": path.resolve(__dirname, 'src/astarte-client/')
    }
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
    new webpack.ProvidePlugin({
      process: 'process/browser',
    }),
  ],
};
