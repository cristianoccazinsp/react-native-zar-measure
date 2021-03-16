import React from "react";
import { requireNativeComponent, NativeModules, ViewStyle, Platform,
  PermissionsAndroid, Text, SafeAreaView, findNodeHandle
 } from "react-native";


const ZarMeasureModule = NativeModules.ZarMeasureViewManager || NativeModules.ZarMeasureModule;
const Consts = ZarMeasureModule.getConstants();


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
   * if set to true, draws planes in the scene. These are raw estimates of shapes
  */
  showPlanes: boolean,

  /**
   * if set to true, draws geometry in the scene. These are higher accuracy shapes
  */
  showGeometry: boolean,

  /**
   * if set to true and supported, draws high accuracy meshes in the scene.
   *
   * Check Constants.MESH_SUPPORTED to see if meshes are supported.
  */
  showMeshes: boolean,

  /**
   * If true, will draw the plane of the current hit target result
   */
  showHitPlane: boolean,

  /**
   * If true, will draw the geometry of the current hit target result
   */
  showHitGeometry: boolean,

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
   * Turns on/off torch (flash), if available.
   *
   * default: false
   */
  torchOn: boolean,

  /**
   * Pauses the session.
   *
   * Note: Session is paused automatically on interruptions, so this is likely unneeded.
   *
   */
  paused: boolean,

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
   *
   * location: screen tap location
   */
  onTextTap(evt: {measurement: MeasurementLine, location: {x: number, y: number}}):void,

  /**
   * Called when a detected plane is tapped
   *
   * location: screen tap location
   */
  onPlaneTap(evt: {plane: ARPlane, location: {x: number, y: number}}):void,
}

type MeasurementNode = {
  x: number,
  y: number,
  z: number
}

type MeasurementLine = {
  id: string,
  planeId: string, // if it was added as part of an add plane operation
  node1: MeasurementNode,
  node2: MeasurementNode,
  label: String, // text node label
  distance: number // in meters
}

type MeasurementLine2D = {
  id: string,
  planeId: string, // if it was added as part of an add plane operation
  node1: MeasurementNode,
  node2: MeasurementNode,
  label: String, // text node label
  bounds: {width: number, height: number}, // image bounds
  distance: number // in meters in 3rd world
}

/**
 * x, y coordinates are the plane's center relative to the (0, 0)
 * in the plane given its vertical or horizontal position
 *
 * TODO: Review if these positions are correct
 */
type ARPlane = {
  // plane ID that may be used to perform other operations, not necessarily unique (up to ARKit)
  // as planes change constantly, the plane associated to this ID may live only for a short period of time.
  id: string,

  // x, y, z represent the plane's top-left vertex in the AR world
  x: number,
  y: number,
  z: number,
  width: number,
  height: number,
  vertical: boolean, // true if vertical, false if horizontal plane
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
    intersectDistance: 0.1,
  }

  // ------ Consts ----------------

  static Constants = {
    /** true  if AR is supported on the device */
    AR_SUPPORTED: Consts.AR_SUPPORTED,

    /** true if the device also supports high detail Meshes */
    MESH_SUPPORTED: Consts.MESH_SUPPORTED,
  }


  // ------ Public methods --------

  /**
   * Clears all measurements from the AR scene
   *
   * clear: "all" | "points" | "planes"
   *  by default clears all measurements, otherwise, clear only those added by addPoint, or those
   *  added by addPlane
   *
   * vibrate: disables vibration if false
   */
  async clear(clear="all", vibrate=true){
    const handle = findNodeHandle(this._ref.current);
    if(handle){
      await ZarMeasureModule.clear(handle, clear, vibrate);
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
   *
   * clear: "all" | "points" | "planes"
   * if all, clears any previous measurement line
   * if points, only clears previous measurement lines added with addPoint, planes are excluded
   * if planes: only clears the previously added plane (all measurements)
   *
   * in every case, the current active node (if any) will be cleared first and the operation stopped.
   */
  async removeLast(clear="all"){
    const handle = findNodeHandle(this._ref.current);
    if(handle){
      await ZarMeasureModule.removeLast(handle, clear);
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
   * clearPlane: removes plane id from the node so it can be skipped in clear operations
   *
   * Returns updated node, or null if node wasn't found.
   */
  async editMeasurement(id, text, clearPlane=true) : MeasurementLine {
    const handle = findNodeHandle(this._ref.current);
    if(handle){
      return await ZarMeasureModule.editMeasurement(handle, id, text, clearPlane);
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
  async addPoint(setCurrent=false) : {error: string, measurement: MeasurementLine, cameraDistance: number} {
    const handle = findNodeHandle(this._ref.current);
    if(handle){
      return await ZarMeasureModule.addPoint(handle, setCurrent);
    }
    return {error: "View not available"};
  }

  /**
   * Adds measurements to a detected plane and returns all measurement lines and plane info.
   * Note that planes here are AR's raw estimates, and not processed image planes like native apps,
   * useful only for large surfaces (e.g., walls and floors)
   *
   * id: if empty, performs a hit test against the current node,
   * otherwise, attempts to add measurements to the given plane ID
   *
   * left, top, right, bottom: flag to automatically add a measurment line to that edge or not.
   * Pass everything as false to just perform plane detection and get the plane ID.
   *
   * setId: sets the plane ID to the added measurements so they can be referenced later. Set to false
   * to skip it from calls that affect plane measurements.
   */
  async addPlane(id='', left=true, top=true, right=true, bottom=true, setId=true)
   : {error: string, plane: ARPlane, measurements: [MeasurementLine]} {
    const handle = findNodeHandle(this._ref.current);
    if(handle){
      return await ZarMeasureModule.addPlane(handle, id, left, top, right, bottom, setId);
    }
    return {error: "View not available"};
  }

  /**
   * Returns all existing measurements on screen
   */
  async getMeasurements() : [MeasurementLine] {
    const handle = findNodeHandle(this._ref.current);
    if(handle){
      return await ZarMeasureModule.getMeasurements(handle);
    }
    return [];
  }

  /**
   * Returns existing rectangular (rough) planes currently detected in the world.
   *
   * minDimension: excludes planes whose dimensions (width or height) are less than this value (m)
   * alignment: all | vertical | horizontal to filter by alignment
   */
  async getPlanes(minDimension=0, alignment='all') : [ARPlane] {
    const handle = findNodeHandle(this._ref.current);
    if(handle){
      return await ZarMeasureModule.getPlanes(handle, minDimension, alignment);
    }
    return [];
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

  /**
   * Saves an USDZ file (.usdz) to the given path, or resolvves with {error: string}
   * path must include full path, name, and usdz extension.
   *
   * Note: not supported with geometry mode: unknown crash from Apple source code.
   *
   */
  async saveToFile(path) : {error: string} {
    const handle = findNodeHandle(this._ref.current);
    if(handle){
      return await ZarMeasureModule.saveToFile(handle, path);
    }
    return {error: "View not available"};
  }

  /**
   * Invokes Apple's QLPreviewController to preview a given USDZ file
   *
   * Resolves only after the preview modal closes, otherwise, rejects if it fails to open.
   *
   * Only one preview can be opened at a time.
   *
   * NOTE: Work in progress, it always opens through the camera first, which is annoying and
   * oposed to Apple's docs from ARQuickLookPreviewItem. Need a real viewer.
   * */
  static async showPreview(path){
    return await ZarMeasureModule.showPreview(path);
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
      this.onCameraStatusChange && this.onCameraStatusChange(granted);
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
    this.props.onARStatusChange && this.props.onARStatusChange(evt.nativeEvent);
  }

  onMeasuringStatusChange = (evt) => {
    this.props.onMeasuringStatusChange && this.props.onMeasuringStatusChange(evt.nativeEvent);
  }

  onMountError = (evt) => {
    this.props.onMountError && this.props.onMountError(evt.nativeEvent);
  }

  onTextTap = (evt) => {
    this.props.onTextTap && this.props.onTextTap(evt.nativeEvent)
  }

  onPlaneTap = (evt) => {
    this.props.onPlaneTap && this.props.onPlaneTap(evt.nativeEvent)
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
      onPlaneTap,
      ...props
    } = this.props;

    // avoid sending onTextTap and onPlaneTap
    // so vibration is not triggered if not used

    return (
      <NativeZarMeasureView
        {...props}
        ref={this._ref}
        onARStatusChange={this.onARStatusChange}
        onMeasuringStatusChange={this.onMeasuringStatusChange}
        onMountError={this.onMountError}
        onTextTap={onTextTap ? this.onTextTap : undefined}
        onPlaneTap={onPlaneTap ? this.onPlaneTap : undefined}
      />
    )
  }
}

const NativeZarMeasureView = requireNativeComponent("ZarMeasureView", ZarMeasureView, {
  nativeOnly: {
  }
});

