#pragma OPENCL EXTENSION cl_khr_global_int32_base_atomics : enable
#pragma OPENCL EXTENSION cl_khr_local_int32_base_atomics : enable
__kernel void SetHorspoolMatch(
	__global const char *haystack, 
	__global const char *needlesData, //Problem here can I pass a point array and still using it
	__global const int *skipTable, //Put it into local memory
	int longestNeedleLen, //It is used for overlaping
	int charsPerItem,
	int needleNum,
	__local int *localCounter,
	__global const int *lastPosOfEachNeedle,
	__global const int *lenOfEachNeedle,
	__global int *res//cant write to res array, write res to local var when finish processing then write to res global
	) {
		
	int j;	
	//Set LocalCounter	
	int privateCounter[20];
	for(j=0;j<20;j++){
		privateCounter[j] = 0;
	}
	
	int localIndex = get_local_id(0);
	
	if(localIndex < needleNum){
		localCounter[localIndex] = 0;
	}
	
	//Syncing here
	barrier(CLK_LOCAL_MEM_FENCE | CLK_GLOBAL_MEM_FENCE);
	
	//Data blocking	
    int index = get_global_id(0);
    int offset = 0;
    if(index != 0){
		offset = index*charsPerItem;
		//The overlaping is the longest needle length - 1 but it can case short needle be counted more than once, 
		//but when using bit array to record the result this issue can be avoided. 
	}
	//Dividing needles buffer into individual needle
	//I did not do that instead of that I used a pass offset
	
	//Matching processing
	j=0;
    while(j<=charsPerItem) {//How about the last work_item, the charsPerItem already minus the shortest needles length!!!(note)
        int k;
        int shift = longestNeedleLen;
        int pass=0;//Pass offset
        for(k=0; k<needleNum; k++) {
            int lastPosOfThisNeedle = lastPosOfEachNeedle[k];
            while(lastPosOfThisNeedle>=0 && needlesData[lastPosOfThisNeedle+pass]==haystack[offset+lastPosOfThisNeedle+j]) {
                lastPosOfThisNeedle--;
            }
            if(lastPosOfThisNeedle<0) {
                privateCounter[k]++;
            }
            int jump = skipTable[(int)haystack[offset+j+lastPosOfThisNeedle]];
            if(jump >= 1 && shift > jump){
				shift = jump;
			}
			pass = pass+lenOfEachNeedle[k];  
        }
        j+= shift;
    }
    
    //Sending res from private mem to local mem
    for(j=0;j<needleNum;j++){
		atomic_add(&localCounter[j], privateCounter[j]);
	}
	
	//Syncing here
	barrier(CLK_LOCAL_MEM_FENCE | CLK_GLOBAL_MEM_FENCE);
	
    //Save local counter to global res 
	if(localIndex == 0){
		size_t groupID = get_group_id(0);//Group ID
		for(j=0;j<needleNum;j++){
			res[j+groupID*needleNum] = localCounter[j];
		}		
	}

}
