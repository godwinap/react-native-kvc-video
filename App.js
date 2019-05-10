import React, { Component } from 'react';
import Video from './src/components/KVCVideo';
export default class App extends Component {
  render() {
    const playBtnImg = require('./src/assets/img/player_play_button.png');
    const pauseBtnImg = require('./src/assets/img/player_pause_button.png');
    return <React.Fragment>
      <Video
      style={{ flex: 1 }}
      playBtnImg={playBtnImg}
      pauseBtnImg={pauseBtnImg}
      source={{
        uri: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
      }} />
    </React.Fragment>
  }
}