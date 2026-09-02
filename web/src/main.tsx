import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';

import { App } from './app';
import './gaya.css';

const akar = document.getElementById('akar');
if (!akar) throw new Error('Elemen #akar tidak ada di index.html.');

createRoot(akar).render(
  <StrictMode>
    <BrowserRouter>
      <App />
    </BrowserRouter>
  </StrictMode>,
);
