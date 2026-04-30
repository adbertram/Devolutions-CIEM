const fs = require('fs');
const path = require('path');

const root = path.resolve(__dirname, '..');
const distDir = path.join(root, 'dist');
const echartsPath = require.resolve('echarts/dist/echarts.min.js');
const componentPath = path.join(root, 'src', 'ciem-environment-tree.js');
const outputPath = path.join(distDir, 'index.bundle.js');

fs.mkdirSync(distDir, { recursive: true });

const echarts = fs.readFileSync(echartsPath, 'utf8');
const component = fs.readFileSync(componentPath, 'utf8');
const bundle = [
  '/* CIEM Environment Tree bundle. ECharts is sourced from npm dependency echarts. */',
  echarts,
  ';',
  component
].join('\n');

fs.writeFileSync(outputPath, bundle, 'utf8');
console.log(`Wrote ${outputPath}`);
