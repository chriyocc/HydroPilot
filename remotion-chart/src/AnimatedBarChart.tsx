import {
  AbsoluteFill,
  Easing,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from 'remotion';

const chartData = [
  {label: 'pH', value: 68, color: '#15b8a6'},
  {label: 'Temp', value: 82, color: '#f97316'},
  {label: 'Light', value: 74, color: '#facc15'},
  {label: 'Flow', value: 58, color: '#38bdf8'},
  {label: 'Nutrients', value: 91, color: '#a855f7'},
];

const maxValue = 100;
const chartHeight = 360;
const staggerFrames = 7;

export const AnimatedBarChart = () => {
  const frame = useCurrentFrame();
  const {fps} = useVideoConfig();

  const titleOpacity = interpolate(frame, [0, 0.7 * fps], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.bezier(0.16, 1, 0.3, 1),
  });

  const ruleProgress = interpolate(frame, [0.25 * fps, 2.1 * fps], [0, 1], {
    extrapolateLeft: 'clamp',
    extrapolateRight: 'clamp',
    easing: Easing.bezier(0.16, 1, 0.3, 1),
  });

  return (
    <AbsoluteFill
      style={{
        background: '#101418',
        color: '#eef7f6',
        fontFamily:
          'Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
        padding: 72,
      }}
    >
      <div
        style={{
          opacity: titleOpacity,
          transform: `translateY(${interpolate(titleOpacity, [0, 1], [18, 0])}px)`,
        }}
      >
        <div
          style={{
            fontSize: 24,
            color: '#8ea39f',
            letterSpacing: 0,
            marginBottom: 10,
          }}
        >
          HydroPilot system snapshot
        </div>
        <div
          style={{
            fontSize: 62,
            fontWeight: 800,
            letterSpacing: 0,
            lineHeight: 1,
          }}
        >
          Live Growth Metrics
        </div>
      </div>

      <div
        style={{
          position: 'absolute',
          left: 72,
          right: 72,
          bottom: 72,
          height: 448,
          display: 'flex',
          alignItems: 'flex-end',
          gap: 34,
        }}
      >
        <div
          style={{
            position: 'absolute',
            left: 0,
            right: 0,
            bottom: 68,
            height: chartHeight,
            borderBottom: '2px solid rgba(238, 247, 246, 0.18)',
            borderLeft: '2px solid rgba(238, 247, 246, 0.1)',
          }}
        >
          {[0, 1, 2, 3].map((line) => (
            <div
              key={line}
              style={{
                position: 'absolute',
                left: 0,
                right: 0,
                bottom: (chartHeight / 4) * line,
                height: 1,
                background: 'rgba(238, 247, 246, 0.08)',
                transform: `scaleX(${ruleProgress})`,
                transformOrigin: 'left center',
              }}
            />
          ))}
        </div>

        {chartData.map((item, index) => {
          const delayedFrame = frame - index * staggerFrames;
          const grow = spring({
            frame: delayedFrame,
            fps,
            config: {
              damping: 18,
              stiffness: 95,
              mass: 0.65,
            },
          });
          const clampedGrow = Math.min(grow, 1);
          const barHeight = (item.value / maxValue) * chartHeight * clampedGrow;
          const valueOpacity = interpolate(delayedFrame, [18, 34], [0, 1], {
            extrapolateLeft: 'clamp',
            extrapolateRight: 'clamp',
          });

          return (
            <div
              key={item.label}
              style={{
                position: 'relative',
                zIndex: 1,
                width: 190,
                height: 430,
                display: 'flex',
                flexDirection: 'column',
                alignItems: 'center',
                justifyContent: 'flex-end',
              }}
            >
              <div
                style={{
                  opacity: valueOpacity,
                  fontSize: 38,
                  fontWeight: 800,
                  marginBottom: 14,
                }}
              >
                {Math.round(item.value * clampedGrow)}
              </div>
              <div
                style={{
                  width: 112,
                  height: barHeight,
                  minHeight: 6,
                  borderRadius: '8px 8px 2px 2px',
                  background: `linear-gradient(180deg, ${item.color}, rgba(255,255,255,0.16))`,
                  boxShadow: `0 22px 48px ${item.color}55`,
                }}
              />
              <div
                style={{
                  height: 54,
                  display: 'flex',
                  alignItems: 'flex-end',
                  fontSize: 24,
                  fontWeight: 700,
                  color: '#c8d8d5',
                }}
              >
                {item.label}
              </div>
            </div>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};
