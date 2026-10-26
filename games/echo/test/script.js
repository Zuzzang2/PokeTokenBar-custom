// Scripted input helper: [[frames, 'lrj'], ...] -> inputAt(frame).
const Core = require('../core.js');

function script(segments) {
  const timeline = segments.flatMap(([n, keys]) => Array.from({ length: n }, () => ({
    l: keys.includes('l'), r: keys.includes('r'), j: keys.includes('j'),
  })));
  return (f) => timeline[f] || { l: false, r: false, j: false };
}

// Play every loop in order; each finished loop becomes an echo for the next.
function playLoops(lvl, loops) {
  return loops.reduce((acc, segments) => {
    const { world, rec } = Core.simulate(lvl, acc.echoes, script(segments));
    return { echoes: [...acc.echoes, rec], last: world };
  }, { echoes: [], last: null });
}

module.exports = { script, playLoops };
