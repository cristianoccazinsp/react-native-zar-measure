import React from "react";
import { requireNativeComponent, NativeModules, ViewStyle, Platform,
  PermissionsAndroid, Text, SafeAreaView, findNodeHandle
 } from "react-native";


const ZarMeasureModule = NativeModules.ZarMeasureViewManager || NativeModules.ZarMeasureModule;
const Consts = ZarMeasureModule.getConstants();
const dummy = () => {};


type ZarMeasureViewProps = {

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

  /** If true, measure error messages and help won't be shown
   *
   * default false
   */
  hideHelp: boolean,

  /** Min distance in meters from the camera to perform detection.
   * Anything smaller than this, will be ignored.
   *
   * default: 0.05
   */
  minDistanceCamera: number,

  /** Max distance in meters from the camera to perform detection.
   * Anything bigger than this, will be ignored.
   *
   * default: 1
   */
  maxDistanceCamera: number,

  /**
   * Callback fired when authorization has changed
   *
   * authorized: true if auth was given, false otherwise
  */
  onCameraStatusChange(authorized): void,

  /**
   * Fired with AR tracking satus updates
   *
   * status: off | no_anchors | not_available | excessive_motion | insufficient_features | initializing | ready
  */
  onStatusChange(evt: {status: string}):void,

  /** Fired if there was a camera mount error */
  onMountError(err: { message: string }): void,

  /** Fired when a new detection has been made
   *
   * cameraDistance: meters
  */
  onDetect(evt: { cameraDistance: number }): void,

  /** Fired when two points have been measured and drawn with acceptable accuracy
   *
   * distance: meters (regardless of units)
   * cameraDistance: meters
  */
  onMeasure(evt: { distance: number, cameraDistance: number }): void,

  /** Fired when measure attempt / detection fails */
  onMeasureError(err: { message: string }): void,
}


type ZarMeasureViewConsts = {

  /**
   * AR_SUPPORTED: true/false to indicate if AR is supported on the device
  */
  AR_SUPPORTED: boolean
}




export const androidCameraPermissionOptions = {
  title: 'Permission to use camera',
  message: 'We need your permission to use your camera.',
  buttonPositive: 'Ok',
  buttonNegative: 'Cancel',
}

let ZarMeasureConsts : ZarMeasureViewConsts = Consts;


export default class ZarMeasureView extends React.Component<ZarMeasureViewProps>{
  static defaultProps = {
    androidCameraPermissionOptions: androidCameraPermissionOptions,
    pendingAuthorizationView: <SafeAreaView><Text>Loading...</Text></SafeAreaView>,
    notAuthorizedView: <SafeAreaView><Text>Not Authorized</Text></SafeAreaView>,
    units: 'm',
    hideHelp: false,
    minDistanceCamera: 0.05,
    maxDistanceCamera: 1,
    onCameraStatusChange: dummy,
    onStatusChange: dummy,
    onMountError: dummy,
    onDetect: dummy,
    onMeasure: dummy,
    onMeasureError: dummy
  }



  // ------ Public methods --------

  /**
   * Clears all drawings from the AR scene
   */
  async clear(){
    const handle = findNodeHandle(this._ref.current);
    if(handle){
      await ZarMeasureModule.clear(handle);
    }
  }

  // ------------------------------------------------


  constructor(props){
    super(props);
    this.state = {
      authorized: false,
      authChecked: false
    }

    this._ref = React.createRef();
    this.requestPermissions = this.requestPermissions.bind(this);
    this.clear = this.clear.bind(this);
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

  onStatusChange = (evt) => {
    this.props.onStatusChange(evt.nativeEvent);
  }

  onMountError = (evt) => {
    this.props.onMountError(evt.nativeEvent);
  }

  onDetect = (evt) => {
    this.props.onDetect(evt.nativeEvent);
  }

  onMeasure = (evt) => {
    this.props.onMeasure(evt.nativeEvent);
  }

  onMeasureError = (evt) => {
    this.props.onMeasureError(evt.nativeEvent);
  }

  render(){
    let {authChecked, authorized} = this.state;

    if(!authChecked){
      return this.props.pendingAuthorizationView;
    }
    if(!authorized){
      return this.props.notAuthorizedView;
    }

    let {
      onCameraStatusChange,
      onStatusChange,
      onMountError,
      onDetect,
      onMeasure,
      onMeasureError,
      ...props
    } = this.props;

    return (
      <NativeZarMeasureView
        {...props}
        ref={this._ref}
        onStatusChange={this.onStatusChange}
        onMountError={this.onMountError}
        onDetect={this.onDetect}
        onMeasure={this.onMeasure}
        onMeasureError={this.onMeasureError}
      />
    )
  }
}

const NativeZarMeasureView = requireNativeComponent("ZarMeasureView", ZarMeasureView, {
  nativeOnly: {
  }
});


export {ZarMeasureConsts};
