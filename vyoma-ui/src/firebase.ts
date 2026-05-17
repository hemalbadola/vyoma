import { initializeApp } from 'firebase/app'
import { getAuth } from 'firebase/auth'

/** Same Firebase project as the Flutter app (`vyoma-in`). */
const firebaseConfig = {
  apiKey: 'AIzaSyD2RYGwSOJZ6xTkLtr2K1ErUDyzn7bs5cM',
  authDomain: 'vyoma-in.firebaseapp.com',
  projectId: 'vyoma-in',
  storageBucket: 'vyoma-in.firebasestorage.app',
  messagingSenderId: '126666832937',
  appId: '1:126666832937:web:8adc6251dd8793fb053038',
}

const app = initializeApp(firebaseConfig)
export const auth = getAuth(app)
