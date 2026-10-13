const sharp = require('sharp');
// Regenerate with: node scripts/make-icons.cjs
const root = require('path').resolve(__dirname, '..');
const svg = `${root}/public/favicon.svg`;
sharp(svg, { density: 384 }).resize(32, 32).png().toFile(`${root}/public/favicon-32.png`);
// Apple touch icons can't be transparent, so put the logo on white with padding.
sharp(svg, { density: 384 })
	.resize(140, 140)
	.extend({ top: 20, bottom: 20, left: 20, right: 20, background: '#ffffff' })
	.flatten({ background: '#ffffff' })
	.png()
	.toFile(`${root}/public/apple-touch-icon.png`)
	.then((i) => console.log('apple-touch-icon', i.width, i.height));
