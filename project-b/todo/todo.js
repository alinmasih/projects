const fs = require('fs');
const { json } = require('stream/consumers');
const filePath = './todo.json';

const loadTask = ()=>{
try {
    const dataBuff = fs.readFileSync(filePath);
    const dataJSON = dataBuff.toString();
    return JSON.parse(dataJSON) //JSON to js object
} catch (error) {
    return[]
}

}

const saveTask =(tasks)=>{
    const dataJSON = JSON.stringify(tasks) //converts js object into JSON
    fs.writeFileSync(filePath, dataJSON);
}
const addTask = (task)=>{
    const tasks =loadTask();
    tasks.push({task});
    saveTask(tasks);
    console.log("task is saved");
}

const listTask=()=>{
    const tasks = loadTask();
    tasks.forEach((task, index)=>{console.log(`${index+1} - ${task.task}`)});
}


const command = process.argv[2];
const argument = process.argv[3];

if(command==='add'){
    addTask(argument);
}else if(command==='remove'){
    removeTask(parseInt(argument));
}
else if(command==='list'){
    listTask();
}
else{console.log("the command is not found")}