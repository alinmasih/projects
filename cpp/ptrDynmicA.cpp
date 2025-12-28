#include <iostream>
using namespace std;

int main(){
    //the problem with array that they are defined in stack
    // and if we want to change the size of the array
    //it is not possible
    int *p= new int[20];
    delete []p;
    p=nullptr;
    p = new int[40];

    
    return 0;
}