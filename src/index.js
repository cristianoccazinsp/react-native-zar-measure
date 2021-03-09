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

  /**
   * if set to true, draws detected plane anchors
   * default: false
  */
  debugMode: boolean,

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

  /** Distance between nodes to use for node intersection, scaled based on camera distance.
   *
   * scale is cameraDistance * this value, that is, at 1m, intersectDistance is used.
   *
   * default: 0.1
   */
  intersectDistance: number,

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
  onMountError(err: { message: string }): void,

  /**
   * Called when a measurement label is tapped.
   */
  onTextTap(evt: {measurement: MeasurementLine, location: {x: number, y: number}}):void,
}

type MeasurementNode = {
  x: number,
  y: number,
  z: number
}

type MeasurementLine = {
  id: string,
  node1: MeasurementNode,
  node2: MeasurementNode,
  label: String, // text node label
  distance: number // in meters
}

type MeasurementLine2D = {
  id: string,
  node1: MeasurementNode,
  node2: MeasurementNode,
  label: String, // text node label
  bounds: {width: number, height: number}, // image bounds
  distance: number // in meters in 3rd world
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
    debugMode: false,
    units: 'm',
    minDistanceCamera: 0.05,
    maxDistanceCamera: 5,
    intersectDistance: 0.1,
    onCameraStatusChange: dummy,
    onARStatusChange: dummy,
    onMeasuringStatusChange: dummy,
    onMountError: dummy,
    onTextTap: dummy
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
   * Clears the current measuring step, if any.
   */
  async clearCurrent(){
    const handle = findNodeHandle(this._ref.current);
    if(handle){
      await ZarMeasureModule.clearCurrent(handle);
    }
  }

  /**
   * Removes the last added measurement, if any, or removes the previously
   * added partial node (stops current measurement).
   */
  async removeLast(){
    const handle = findNodeHandle(this._ref.current);
    if(handle){
      await ZarMeasureModule.removeLast(handle);
    }
  }

  /**
   * Removes a measurmenet by index and returns its data or null if none
   *
   * Returns MeasurementLine or null if nothing was removed
   */
  async removeMeasurement(id) : MeasurementLine {
    const handle = findNodeHandle(this._ref.current);
    if(handle){
      return await ZarMeasureModule.removeMeasurement(handle, id);
    }
  }

  /**
   * Edits an existing measurement text node, setting a custom text.
   *
   * Returns updated node, or null if node wasn't found.
   */
  async editMeasurement(id, text) : MeasurementLine {
    const handle = findNodeHandle(this._ref.current);
    if(handle){
      return await ZarMeasureModule.editMeasurement(handle, id, text);
    }
  }

  /**
   * Adds a new point in the currently detected node.
   * If it was the first point added, only returns camera distance,
   * otherwise, resolves with both distance and measurement
   * Lastly, if there were 2 points already, it is the same as calling clear and error is "Cleared"
   *
   * setCurrent: while adding the point, also makes the new point the current point for a new measure
   * error will be a string if the add point operation failed.
   *
   * measurement.distance: distance in meters (regarldess of unit)
   * cameraDistance: camera distance in meters
   */
  async addPoint(setCurrent=false) : {added: boolean, error: string, measurement: MeasurementLine, cameraDistance: number} {
    const handle = findNodeHandle(this._ref.current);
    if(handle){
      return await ZarMeasureModule.addPoint(handle, setCurrent);
    }
    return {error: "View not available", added: false};
  }

  /**
   * Returns all existing measurements on screen
   */
  async getMeasurements() : [MeasurementLine] {
    const handle = findNodeHandle(this._ref.current);
    if(handle){
      return await ZarMeasureModule.getMeasurements(handle);
    }
    return {error: "View not available", added: false};
  }

  /**
   * Takes a PNG picture of the current scene and saves it into the given path
   *
   * where measurements are in the 2D coordinate of the image (0,0 is top left).
   * Only those nodes which are in the picture are returned.
   */
  async takePicture(path) : {error: string, measurements: [MeasurementLine2D]} {
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

  onTextTap = (evt) => {
    this.props.onTextTap(evt.nativeEvent)
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
      onTextTap,
      ...props
    } = this.props;

    return (
      <NativeZarMeasureView
        {...props}
        ref={this._ref}
        onARStatusChange={this.onARStatusChange}
        onMeasuringStatusChange={this.onMeasuringStatusChange}
        onMountError={this.onMountError}
        onTextTap={this.onTextTap}
      />
    )
  }
}

const NativeZarMeasureView = requireNativeComponent("ZarMeasureView", ZarMeasureView, {
  nativeOnly: {
  }
});

