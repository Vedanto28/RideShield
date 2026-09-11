import React from 'react';
import { MapContainer, TileLayer, Marker, Popup } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';

// Custom modern pulsing dot icon to replace default leaflet pin
const createRedDotIcon = () => {
  return L.divIcon({
    className: 'custom-div-icon',
    html: `
      <div style="
        width: 20px; 
        height: 20px; 
        background-color: #EF4444; 
        border-radius: 50%; 
        border: 3px solid white; 
        box-shadow: 0px 4px 10px rgba(239, 68, 68, 0.4);
        position: relative;
        left: -10px;
        top: -10px;
      ">
        <div style="
          width: 14px; 
          height: 14px; 
          background-color: #EF4444; 
          border-radius: 50%; 
          position: absolute;
          top: 0;
          left: 0;
          animation: ping 1.5s cubic-bezier(0, 0, 0.2, 1) infinite;
        "></div>
      </div>
    `,
    iconSize: [20, 20],
    iconAnchor: [0, 0]
  });
};

export default function IncidentMap({ latitude, longitude, height = "h-40" }) {
  if (!latitude || !longitude) {
    return (
      <div className={`bg-surface-muted rounded-xl border border-surface-border relative overflow-hidden ${height} flex items-center justify-center`}>
        <span className="text-on-surface-variant font-medium text-[13px]">GPS Data Unavailable</span>
      </div>
    );
  }

  const position = [latitude, longitude];

  return (
    <div className={`rounded-xl border border-surface-border relative overflow-hidden ${height}`}>
      <MapContainer 
        center={position} 
        zoom={15} 
        scrollWheelZoom={false} 
        style={{ height: '100%', width: '100%', zIndex: 1 }}
        attributionControl={false}
      >
        <TileLayer
          url="https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png"
        />
        <Marker position={position} icon={createRedDotIcon()}>
          <Popup>
            <div className="text-center font-mono text-[11px] font-bold text-on-surface">
              {latitude.toFixed(4)}°N, {longitude.toFixed(4)}°E
            </div>
          </Popup>
        </Marker>
      </MapContainer>
    </div>
  );
}
