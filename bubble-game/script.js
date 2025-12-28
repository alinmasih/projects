let clutter = "";
const bubbleMaker = ()=>{
for(i = 1; i< 193; i++){

    let num = Math.floor(Math.random()*10);
    clutter+= `<div class="bubble">
                    ${num}
                </div>`;
}

document.querySelector("#console-body").innerHTML= clutter;
}

let timer = 60;
const timerRun = ()=>{
let timerint = setInterval(()=>{
    if( timer>0){
        timer --;
    document.querySelector("#timer").innerHTML=timer;
    }
    else{
        clearInterval(timerint);
        // document.querySelector("#console-body").innerHTML=`<h1>Game Over</h1>`;
    }
    
},1000);
}

let hit = 0
const newHit =() =>{
hit = Math.floor ( Math.random()*10);

document.querySelector("#hit").innerHTML= hit;
}

let score = 0;
const scoreInc =()=>{
    score +=10;
    document.querySelector("#score").innerHTML=score;
}

bubbleMaker();
timerRun();
newHit();


let hitval = 0
document.querySelector("#console-body")
.addEventListener("click",function(dets){
    hitval = Number(dets.target.textContent);
    if(hit===hitval){
         scoreInc();
         bubbleMaker();
         newHit();
}
});




  




