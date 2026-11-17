import React from 'react';
import {Composition, registerRoot} from 'remotion';
import {EditedFilm,Film} from './video.jsx';
import revision from './revision.json';

const Root = () => <>
  <Composition id="SaltlineFilm" component={EditedFilm} width={1920} height={1080} fps={60} durationInFrames={revision.totalFrames} />
  <Composition id="FirstCut" component={Film} width={1920} height={1080} fps={60} durationInFrames={640 * 60} />
</>;
registerRoot(Root);
