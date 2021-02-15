import React from "react";
import { requireNativeComponent, NativeModules, ViewStyle, Platform,
  PermissionsAndroid, Text, SafeAreaView
 } from "react-native";


const ZarMeasureModule = NativeModules.ZarMeasureViewManager || NativeModules.ZarMeasureModule;
const Consts = ZarMeasureModule.getConstants();


type Props = {

  style: ViewStyle,

  /** Android permissions rationale */
  androidCameraPermissionOptions: {
    title: string,
    message: striing,
    buttonPositive: string,
    buttonNegative: string
  },

  /** View to render while auth is pending */
  pendingAuthorizationView: React.Component,

  /** View to render if auth is not given */
  notAuthorizedView: React.Component,

  /** Units to render labels */
  units: 'm' | 'ft',

  /**
   * Callback fired when authorization has changed
   *
   * authorized: true if auth was given, false otherwise
  */
  onStatusChange(authorized): void,

  /** Fired when the component is is ready
   *
   * Note: ARKit does not provide a ready function, so onMountError may fire afterwards
  */
  onReady():void,

  /** Fired if there was a camera mount error */
  onMountError(err: { message: string }): void,

  /** Fired when two points have been measured and drawn with acceptable accuracy
   *
   * distance: meters (regardless of units)
  */
  onMeasure(evt: { distance: number }): void,
}

export const androidCameraPermissionOptions = {
  title: 'Permission to use camera',
  message: 'We need your permission to use your camera.',
  buttonPositive: 'Ok',
  buttonNegative: 'Cancel',
}


const dummy = () => {};

export default class ZarMeasureView extends React.Component<Props>{
  static defaultProps = {
    androidCameraPermissionOptions: androidCameraPermissionOptions,
    pendingAuthorizationView: <SafeAreaView><Text>Loading...</Text></SafeAreaView>,
    notAuthorizedView: <SafeAreaView><Text>Not Authorized</Text></SafeAreaView>,
    units: 'm',
    onStatusChange: dummy,
    onReady: dummy,
    onMountError: dummy,
    onMeasure: dummy
  }

  static Consts = Consts


  constructor(props){
    super(props);
    this.state = {
      authorized: false,
      authChecked: false
    }

    this.requestPermissions = this.requestPermissions.bind(this);
  }


  async componentDidMount(){
    this._mounted = true;
    const granted = await this.requestPermissions();

    if(this._mounted){
      this.setState({
        authorized: granted,
        authChecked: true
      });
    }
  }

  componentWillUnmount(){
    this._mounted = false;
  }

  async requestPermissions(){
    let permGranted = false;

    if (Platform.OS === 'ios') {
      permGranted = await ZarMeasureModule.checkVideoAuthorizationStatus();
    }
    else if (Platform.OS === 'android') {
      const cameraPermissionResult = await PermissionsAndroid.request(
        PermissionsAndroid.PERMISSIONS.CAMERA,
        this.props.androidCameraPermissionOptions,
      );

      if (typeof cameraPermissionResult === 'boolean') {
        permGranted = cameraPermissionResult;
      } else {
        permGranted = cameraPermissionResult === PermissionsAndroid.RESULTS.GRANTED;
      }
    }
    else {
      throw new Error("Platform not supported.");
    }

    return permGranted;
  }

  onMountError = (evt) => {
    this.props.onMountError({message: evt.nativeEvent.message});
  }

  onMeasure = (evt) => {
    this.props.onMeasure({distance: evt.nativeEvent.distance});
  }

  render(){
    let {authChecked, authorized} = this.state;

    if(!authChecked){
      return this.props.pendingAuthorizationView;
    }
    if(!authorized){
      return this.props.notAuthorizedView;
    }

    let {onMountError, onMeasure, ...props} = this.props;

    return (
      <NativeZarMeasureView
        {...props}
        onMountError={this.onMountError}
        onMeasure={this.onMeasure}
      />
    )
  }
}

const NativeZarMeasureView = requireNativeComponent("ZarMeasureView", ZarMeasureView, {
  nativeOnly: {
  }
});
