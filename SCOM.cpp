#include<bits\stdc++.h>
using namespace std;
/*
	Simple Calender and Output Manager aka. SCOM
	by Alittlezhi.
*/
const string SAVEFILE ="SCOM.save";
bool saveExists(const string& save){	//判断存档是否存在
	ifstream file(save);
	return file.good();
}
int init_SCOM(){
	if(saveExists(SAVEFILE)){
		//存档存在
		ifstream inFile("SCOM.save");	//打开存档
		if(inFile.is_open()){
			
		}
	}else{
		//存档不存在
		ofstream outFile("SCOM.save");	//创建存档
	}
}
int mainUI() {
	/*
	打印主页
	print mainUI
	*/
	cout << "Simple Calender and Output Manager";
	return 0;
}
int main() {
	init_SCOM();
	mainUI();
	return 0;
}
