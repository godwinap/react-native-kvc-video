import React, { Component } from 'react';
import { Platform, StyleSheet, Text, View, requireNativeComponent, Image } from 'react-native';
// import Video from 'react-native-video';
import Video from './src/components/KVCVideo';
export default class App extends Component {
  render() {
    const HelloWorldSquare = requireNativeComponent('HelloWorldSquare');
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

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    backgroundColor: '#F5FCFF',
  },
  welcome: {
    fontSize: 20,
    textAlign: 'center',
    margin: 10,
  },
  instructions: {
    textAlign: 'center',
    color: '#333333',
    marginBottom: 5,
  },
});