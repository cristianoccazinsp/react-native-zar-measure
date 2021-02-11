import React from "react";
import { requireNativeComponent, ViewStyle, Platform, Text } from "react-native";

const platform = Platform.OS;
const notImplementedView = <Text>Not implemented.</Text>;

type Props = {
  //onImageLoaded?: () => void;
  style: ViewStyle;
}

export default class ZarMeasureView extends React.Component<Props>{

  render(){
    return {
      platform == 'ios' ?
        <NativeZarMeasureView
          {...this.props}
        />
      : notImplementedView
    }
}

const NativeZarMeasureView = requireNativeComponent("ZarMeasureView", ZarMeasureView, {
  nativeOnly: {
  }
});
