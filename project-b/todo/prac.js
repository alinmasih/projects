const fs = require('fs');
const filePath = './prac.json';

const command = process.argv[1];
const argument = process.argv[2];

const loadTask =()=>{
    try {
       const dataBuff = fs.readFileSync(filePath);
       const dataJSON = dataBuff.toString();
       return JSON.parse(dataJSON); 
    } catch (error) {
        return []
    }
}

if(command==='add'){
    addTask();
}
else if(command==='list'){
    listTask();
}
else if(command==='remove'){
    removeTask();
}
else {
    console.log("please enter a correct command")
}