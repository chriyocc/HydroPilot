import {Composition} from 'remotion';
import {AnimatedBarChart} from './AnimatedBarChart';

export const RemotionRoot = () => {
  return (
    <Composition
      id="AnimatedBarChart"
      component={AnimatedBarChart}
      durationInFrames={150}
      fps={30}
      width={1280}
      height={720}
    />
  );
};
