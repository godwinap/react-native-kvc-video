import React, { Component } from 'react';
import {Text, View, ScrollView} from 'react-native';
import VideoScreen from './src/components/KVCVideo';
export default class App extends Component {
  render() {
    const playBtnImg = require('./src/assets/img/player_play_button.png');
    const pauseBtnImg = require('./src/assets/img/player_pause_button.png');
    const rewindBtnImg = require('./src/assets/img/player_rewind_icon.png');
    const forwardBtnImg = require('./src/assets/img/player_forward_icon.png');
    const seekbarCursorImg = require('./src/assets/img/seekbar_curser.png');
    const seekbarCursorActiveImg = require('./src/assets/img/seekbar_curser_highlight.png');
    const fullscreenImg = require('./src/assets/img/player_fullscreen_icon.png');
    return <React.Fragment>
      <VideoScreen
        style={{ flex: 1 }}
        playBtnImg={playBtnImg}
        pauseBtnImg={pauseBtnImg}
        rewindBtnImg={rewindBtnImg}
        forwardBtnImg={forwardBtnImg}
        seekbarCursorImg={seekbarCursorImg}
        seekbarCursorActiveImg={seekbarCursorActiveImg}
        fullscreenImg={fullscreenImg}
        seekbarMaxTint="#EDEDED"
        seekbarMinTint="#ED3636"
        source={{
          uri: "http://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"
        }} >
          <View style={{flex:1, padding:5}}>
              <Text style={{color:'black', fontSize:24, marginTop: 15, marginBottom: 5}}>Video Details UI Container</Text>
              <Text style={{color:'black', fontSize:18, marginBottom: 15}}>Supports all react native elements as children.</Text>
              <ScrollView>
                  <Text style={{color:'black'}}>
                  Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.
                  Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.
                  Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.
                  Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.
                  Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.
                  Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry's standard dummy text ever since the 1500s, when an unknown printer took a galley of type and scrambled it to make a type specimen book. It has survived not only five centuries, but also the leap into electronic typesetting, remaining essentially unchanged. It was popularised in the 1960s with the release of Letraset sheets containing Lorem Ipsum passages, and more recently with desktop publishing software like Aldus PageMaker including versions of Lorem Ipsum.
                  </Text>
              </ScrollView>
          </View> 
        </VideoScreen>
    </React.Fragment>
  }
}