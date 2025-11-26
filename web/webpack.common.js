const postCssModulesValues = require("postcss-modules-values")
const path = require('path')
const autoprefixer = require('autoprefixer')

module.exports = {
  entry: './src/index.tsx',
  // 启用文件系统缓存以加快构建速度
  cache: {
    type: 'filesystem',
    buildDependencies: {
      config: [__filename]
    },
    cacheDirectory: path.resolve(__dirname, '.webpack-cache')
  },
  module: {
    rules: [{
      test: /\.css$/,
      use: [{
        loader: 'style-loader',
      },
      {
        loader: 'css-loader',
        options: {
          importLoaders: 1,
          modules: {
            localIdentName: '[name]__[local]__[hash:base64:5]',
          },
        }
      }]
    },
    {
      test: /\.(png|jpe?g|gif|svg)(\?v=\d+\.\d+\.\d+)?$/,
      loader: 'file-loader'
    },
    {
      test: /\.(woff(2)?|ttf|eot|otf)(\?v=\d+\.\d+\.\d+)?$/,
      use: [{
        loader: 'file-loader',
        options: {
          name: '[name].[ext]',
          outputPath: 'fonts/'
        }
      }]
    },
    // All files with a '.ts' or '.tsx' extension will be handled by 'ts-loader'.
    {
      test: /\.tsx?$/,
      loader: "ts-loader",
      options: {
        // 启用 transpileOnly 可以跳过类型检查，加快构建速度
        // 类型检查可以通过单独的 tsc 命令或 IDE 完成
        transpileOnly: process.env.SKIP_TYPE_CHECK === 'true',
        // 启用实验性文件系统缓存
        experimentalFileCaching: true
      }
    },
    {
      test: /\.ico$/,
      loader: 'file-loader'
    }
    ]
  },
  resolve: {
    extensions: ['.tsx', '.ts', '.js', '.json'],
    symlinks: false,
    // 缓存解析结果
    cache: true
  },
  output: {
    filename: 'bundle.js',
    path: path.resolve(__dirname, 'dist'),
    publicPath: '/'
  },
  // 优化构建性能
  optimization: {
    // 在生产构建中，可以启用模块 ID 的确定性命名以利用缓存
    moduleIds: 'deterministic'
  }
};
