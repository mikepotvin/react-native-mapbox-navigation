/* eslint-disable react-native/no-inline-styles */
import React, {useState} from 'react';
import {
  StyleSheet,
  Switch,
  TextInput,
  View,
  Button,
  SafeAreaView,
} from 'react-native';
import MapboxNavigation from '@everdriven/react-native-mapbox-navigation';

export const Configuration = ({
  from: _from,
  to: _to,
  simulated: _simulated,
  onStart,
}) => {
  let [from, setFrom] = useState(_from);
  let [to, setTo] = useState(_to);
  let [simulated, setSimulated] = useState(_simulated);

  return (
    <SafeAreaView style={{flex: 1, marginLeft: 10, marginTop: 10}}>
      <TextInput
        style={{marginBottom: 10}}
        placeholder="From"
        defaultValue={from}
        value={from}
        onChange={e => {
          setFrom(e.target.value);
        }}
      />
      <TextInput
        style={{marginBottom: 10}}
        placeholder="To"
        defaultValue={to}
        value={to}
        onChange={e => {
          setTo(e.target.value);
        }}
      />
      <Switch
        style={{marginBottom: 10}}
        value={simulated}
        onValueChange={e => {
          setSimulated(!simulated);
        }}
      />
      <Button title="Start" onPress={() => onStart({from, to, simulated})} />
    </SafeAreaView>
  );
};

export const Navigation = ({from, to, simulated}) => {
  console.log(' => Navigate from:', from, 'to:', to, 'simulate:', simulated);
  return (
    <View style={styles.container}>
      <MapboxNavigation
        origin={from}
        destination={to}
        shouldSimulateRoute={simulated}
        showsEndOfRouteFeedback
        onLocationChange={event => {
          const {latitude, longitude} = event.nativeEvent;
          console.log('onLocationChange => lat, lng', latitude, longitude);
        }}
        onRouteProgressChange={event => {
          const {
            distanceTraveled,
            durationRemaining,
            fractionTraveled,
            distanceRemaining,
          } = event.nativeEvent;

          console.log(
            'onRouteProgressChange =>',
            distanceTraveled,
            durationRemaining,
            fractionTraveled,
            distanceRemaining,
          );
        }}
        onError={event => {
          const {error} = event.nativeEvent;

          console.log('onError =>', error);
        }}
        onCancelNavigation={() => {
          // User tapped the "X" cancel button in the nav UI
          // or canceled via the OS system tray on android.
          // Do whatever you need to here.
          console.log('onCancelNavigation =>');
        }}
        onArrive={() => {
          // Called when you arrive at the destination.
          console.log('onArrive');
        }}
      />
    </View>
  );
};

function location(input) {
  if (Array.isArray(input)) {
    return input;
  } else {
    return input.split(',').map(parseFloat);
  }
}

export default function App() {
  const [settings, setSettings] = useState({
    from: [-97.760288, 30.273566],
    to: [-97.918842, 30.494466],
    simulated: true,
  });
  const [configured, setConfigured] = useState(false);

  if (configured) {
    return (
      <Navigation
        from={settings.from}
        to={settings.to}
        simulated={settings.simulated}
      />
    );
  } else {
    return (
      <Configuration
        from={settings.from.map(String).join(',')}
        to={settings.to.map(String).join(',')}
        simulated={settings.simulated}
        onStart={({from, to, simulated}) => {
          console.log('On start', {from, to, simulated});
          setSettings({
            ...settings,
            from: location(from),
            to: location(to),
            simulated: simulated,
          });
          setConfigured(true);
        }}
      />
    );
  }
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
});
