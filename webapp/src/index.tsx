import ReactDOM from 'react-dom';
import './index.css';
import App from './App';
import { BrowserRouter } from 'react-router-dom';
const basename = process.env.REACT_APP_BASENAME;

ReactDOM.render(
  <BrowserRouter basename={basename}>
    <App />
  </BrowserRouter>,
  document.getElementById('root')
);
