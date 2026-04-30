(function () {
  const React = window.React || window.react;
  const UniversalDashboard = window.UniversalDashboard;
  const echarts = window.echarts;

  if (!React) {
    throw new Error('React is required for the CIEM environment tree component.');
  }
  if (!UniversalDashboard) {
    throw new Error('UniversalDashboard is required for the CIEM environment tree component.');
  }
  if (!echarts) {
    throw new Error('ECharts is required for the CIEM environment tree component.');
  }

  const withComponentFeatures = UniversalDashboard.withComponentFeatures || ((component) => component);

  function CIEMEnvironmentTree(props) {
    const containerRef = React.useRef(null);
    const id = props.id;
    const data = props.data;
    const orientation = props.orientation || 'LR';
    const height = props.height || 700;

    React.useEffect(() => {
      const container = containerRef.current;
      if (!container) {
        throw new Error('CIEM environment tree container was not mounted.');
      }

      const existing = echarts.getInstanceByDom(container);
      if (existing) {
        existing.dispose();
      }

      const bgColor = window.getComputedStyle(document.body).backgroundColor;
      let isDark = false;
      if (bgColor) {
        const match = bgColor.match(/\d+/g);
        if (match) {
          const r = parseInt(match[0], 10);
          const g = parseInt(match[1], 10);
          const b = parseInt(match[2], 10);
          isDark = (r * 0.299 + g * 0.587 + b * 0.114) < 128;
        }
      }

      const chart = echarts.init(container, isDark ? 'dark' : null);
      const isLR = orientation === 'LR';
      chart.setOption({
        backgroundColor: 'transparent',
        tooltip: {
          trigger: 'item',
          triggerOn: 'mousemove',
          confine: true,
          formatter: function (params) {
            const d = params.data.value || {};
            const lines = ['<b>' + params.name + '</b>'];
            const parts = (d.tooltip || '').split('|');
            for (let i = 0; i < parts.length; i += 1) {
              if (parts[i]) {
                lines.push(parts[i]);
              }
            }
            return lines.join('<br/>');
          }
        },
        series: [{
          type: 'tree',
          data: [data],
          top: isLR ? '2%' : '8%',
          left: isLR ? '18%' : '2%',
          bottom: isLR ? '2%' : '20%',
          right: isLR ? '20%' : '2%',
          symbolSize: function (value, params) {
            return params.data.symbolSize || 10;
          },
          orient: orientation,
          label: {
            show: true,
            position: isLR ? 'left' : 'top',
            verticalAlign: 'middle',
            align: isLR ? 'right' : 'center',
            fontSize: 16,
            fontFamily: '"Roboto","Helvetica","Arial",sans-serif',
            color: isDark ? '#e0e0e0' : '#333',
            formatter: function (params) {
              const name = params.name || '';
              if (name.length > 35) {
                return name.substring(0, 32) + '...';
              }
              return name;
            }
          },
          leaves: {
            label: {
              position: isLR ? 'right' : 'bottom',
              verticalAlign: 'middle',
              align: isLR ? 'left' : 'center'
            }
          },
          lineStyle: {
            color: isDark ? '#555' : '#bbb',
            width: 1.5,
            curveness: 0.5
          },
          emphasis: {
            focus: 'descendant',
            itemStyle: { borderWidth: 2 },
            label: { color: isDark ? '#fff' : '#000', fontSize: 17 }
          },
          expandAndCollapse: true,
          initialTreeDepth: 2,
          animationDuration: 550,
          animationDurationUpdate: 750
        }]
      });

      window.__ciemEnvironmentCharts = window.__ciemEnvironmentCharts || {};
      window.__ciemEnvironmentCharts[id] = chart;

      const resize = function () {
        chart.resize();
      };
      window.addEventListener('resize', resize);

      return function () {
        window.removeEventListener('resize', resize);
        delete window.__ciemEnvironmentCharts[id];
        chart.dispose();
      };
    }, [id, data, orientation, height]);

    return React.createElement('div', {
      id: id,
      ref: containerRef,
      'data-ciem-environment-tree': 'true',
      style: {
        width: '100%',
        height: `${height}px`
      }
    });
  }

  UniversalDashboard.register('ciem-environment-tree', withComponentFeatures(CIEMEnvironmentTree));
}());
