# Start with upstream node-red
FROM nodered/node-red

# Copy package.json to the WORKDIR so npm builds all
# of your added modules for Node-RED
RUN npm install node-red-contrib-opcua-server

# Copy Node-RED project files into place
COPY settings.js ./settings.js
COPY flows_cred.json ./flows_cred.json
COPY flows.json ./flows.json

EXPOSE 1880/tcp

#expose two OPC server ports
EXPOSE 54845/tcp
EXPOSE 54855/tcp

# Start the container normally
CMD ["npm", "start"]
