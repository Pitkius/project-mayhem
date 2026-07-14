import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import CraftApp from './craft/CraftApp';

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <CraftApp />
    <App />
  </React.StrictMode>,
);
