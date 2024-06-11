# Welcome
A simple "Hello World!" app to test deployment methods

- Options to deploy app:
    - To simlpy run the app:
        - `npm start`
        - open `localhost:3000` in browser
    
    - To deploy in Docker:
        - `docker build -t helloworld-flask-nginx:latest .`
        - `docker run -d -p 3000:3000 helloworld-node-js:1.0`
        - open `localhost:3000` in browser