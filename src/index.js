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

  /** Min distance in meters from the camera to perform detection.
   * Anything smaller than this, will be ignored.
   *
   * default: 0.05
   */
  minDistanceCamera: number,

  /** Max distance in meters from the camera to perform detection.
   * Anything bigger than this, will be ignored.
   *
   * default: 5
   */
  maxDistanceCamera: number,

  /** Uses AR feature detection to do target/hit detection.
   * Incrases speed and improves detection under difficult surfaces, but reduces
   * accuracy.
   *
   * default: true
   */
  useFeatureDetection: boolean,

  /**
   * Callback fired when authorization has changed
   *
   * authorized: true if auth was given, false otherwise
  */
  onCameraStatusChange(authorized): void,

  /**
   * Fired with AR tracking satus updates
   *
   * status: off | loading | ready
   *
   * off: undefined, not used
   * loading: AR is working on setting the inital world, and help messages are being shown
   * ready: AR is ready to measure
  */
  onARStatusChange(evt: {status: string}):void,

  /**
   * Fired when tracking is working, but measuring is not possible
   *
   * status: off | ready | error
   * info: string with error details
  */
  onMeasuringStatusChange(evt: {status: string}):void,

  /** Fired if there was a camera mount error */
  onMountError(err: { message: string }): void
}



export const androidCameraPermissionOptions = {
  title: 'Permission to use camera',
  message: 'We need your permission to use your camera.',
  buttonPositive: 'Ok',
  buttonNegative: 'Cancel',
}


export default class ZarMeasureView extends React.Component<ZarMeasureViewProps>{
  static defaultProps = {
    androidCameraPermissionOptions: androidCameraPermissionOptions,
    pendingAuthorizationView: <SafeAreaView><Text>Loading...</Text></SafeAreaView>,
    notAuthorizedView: <SafeAreaView><Text>Not Authorized</Text></SafeAreaView>,
    units: 'm',
    minDistanceCamera: 0.05,
    maxDistanceCamera: 5,
    useFeatureDetection: true,
    onCameraStatusChange: dummy,
    onARStatusChange: dummy,
    onMeasuringStatusChange: dummy,
    onMountError: dummy
  }

  // ------ Consts ----------------

  static Constants = {
    /** true/false to indicate if AR is supported on the device */
    AR_SUPPORTED: Consts.AR_SUPPORTED
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

  /**
   * Adds a new point in the currently detected node.
   * If it was the first point added, only returns camera distance,
   * otherwise, resolves with both distance and cameraDistance
   * Lastly, if there were 2 points already, it is the same as calling clear and error is "Cleared"
   *
   * Resolves {added: bool, error: str, distance: number, cameraDistance: number}
   * error will be a string if the add point operation failed.
   *
   * distance: distance in meters (regarldess of unit)
   * cameraDistance: camera distance in meters
   */
  async addPoint(){
    const handle = findNodeHandle(this._ref.current);
    if(handle){
      return await ZarMeasureModule.addPoint(handle);
    }
    return {error: "View not available", added: false};
  }

  /**
   * Takes a PNG picture of the current scene and saves it into the given path
   *
   * Resolves ({error: str})
   */
  async takePicture(path){
    const handle = findNodeHandle(this._ref.current);
    if(handle){
      return await ZarMeasureModule.takePicture(handle, path);
    }
    return {error: "View not available"};
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
    this.addPoint = this.addPoint.bind(this);
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

  onARStatusChange = (evt) => {
    this.props.onARStatusChange(evt.nativeEvent);
  }

  onMeasuringStatusChange = (evt) => {
    this.props.onMeasuringStatusChange(evt.nativeEvent);
  }

  onMountError = (evt) => {
    this.props.onMountError(evt.nativeEvent);
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
      onARStatusChange,
      onMeasuringStatusChange,
      onMountError,
      ...props
    } = this.props;

    return (
      <NativeZarMeasureView
        {...props}
        ref={this._ref}
        onARStatusChange={this.onARStatusChange}
        onMeasuringStatusChange={this.onMeasuringStatusChange}
        onMountError={this.onMountError}
      />
    )
  }
}

const NativeZarMeasureView = requireNativeComponent("ZarMeasureView", ZarMeasureView, {
  nativeOnly: {
  }
});

