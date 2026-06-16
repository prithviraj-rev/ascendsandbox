import { LightningElement,  track, api } from 'lwc';
import getCases from '@salesforce/apex/caseViewHelper.getCases';
import caseReviewCheck from '@salesforce/apex/caseViewHelper.caseReviewCheck';

export default class CaseContainer extends LightningElement {
    @api recordId;

    activeCallout;
    pageData = {};
    caseList=[];
    
    @track filteredCaseList;
    filterMap = {};
    filterMapSelected = {};
    filterModalOpen=false;
    filterCol={};
    filterModalTitle='Filter';
    filterModalList=[];
    filterModalListSelected=[];
    picklistOptions;
    tableVersion = 0;

    sortBy = 'CaseNumber';
    sortDirection = 'desc';
    checkStyles;

    searchTerm;

    modalIsFilter=false;
    selectedCase={};

    @track columns = [
        { label: 'Reviewed', fieldName: 'reviewed', sortable: true, searchable: false, actions: [{label:'Filter', name:'filter'}]},
        { label: 'Owner', fieldName: 'ownerName', sortable: true, searchable: false, actions: [{label:'Filter', name:'filter'}]},
        { label: 'Number', fieldName: 'CaseNumber', sortable: true, searchable: true},
        { label: 'Notes', fieldName: 'reviewNotes', sortable: false, searchable: true},
        { label: 'Subject', fieldName: 'Subject', sortable: false, searchable: true},
        
        { label: 'Status', fieldName: 'Status', sortable: true, searchable: false, actions: [{label:'Filter', name:'filter'}]},
        { label: 'Priority', fieldName: 'Priority', sortable: true, searchable: false, actions: [{label:'Filter', name:'filter'}]},
    ];

    connectedCallback(){
        this.modalIsFilter=true;
        this.initializeColumns();
        this.callSelectionSpecs();
        
    }

    initializeColumns(){
        this.columns.forEach(col => {
            if (col.hasOwnProperty("sortable") && col["sortable"]==true){
                col["sortIcon"] = "utility:sort";
            }
            col["filterable"] = (col.hasOwnProperty("actions"))?true:false;
            col["headerVisible"] = (col.hasOwnProperty("actions") || (col.hasOwnProperty("sortable") && col["sortable"]==true))?true:false;
        });
    }


    callSelectionSpecs(){
        this.activeCallout = true;
        getCases({reviewId:this.recordId})
        .then(result=>{
            this.processSelection(result);
            this.activeCallout = false;
            console.log(this.pageData.picklists);
        })
        .catch(error =>{
            console.log('Error: ' + this.error);
            
        });
    }

    processSelection(result){
        this.pageData = result;
        this.caseList = this.pageData.casePool;
        for (var i in this.caseList){
            var c = this.caseList[i];
            c['shortReview'] = '';
            if (c.reviewNotes!=null){
                c['shortReview'] = (c.reviewNotes.length>100)?(c.reviewNotes.substring(0,200)+'...'):c.reviewNotes;
            }
        }
        this.setFilteredCaseList(this.caseList);
        this.pageData.casePool=null;
        this.refreshFilterMap();
    }

    setFilteredCaseList(records){
        this.filteredCaseList = [...records];
        this.tableVersion+=1;
    }


    //populate unique value lists for filterable columns
    refreshFilterMap(){
        this.filterMap = new Object();
        this.columns.forEach(col => {
            if (col.hasOwnProperty("actions")){
                const fieldSet = new Set();
                this.caseList.forEach(c => {
                    var val = (c.hasOwnProperty(col.fieldName))?c[col.fieldName]:null;
                    
                    if (val != null){
                        fieldSet.add(val);
                    }
                });
                this.filterMap[col.fieldName] = Array.from(fieldSet).sort();
                this.filterMap[col.fieldName].unshift("[No value]");
                this.filterMap[col.fieldName].unshift("[Any value]");
                
                if (!this.filterMapSelected.hasOwnProperty(col.fieldName)){
                    this.filterMapSelected[col.fieldName]=new Array();
                }
            }
        });
    }

    handleHeaderAction(event){
        // Retrieves the name of the selected filter
        this.modalIsFilter=true;
        const colDef = this.columns.find((element) => element.fieldName === event.target.dataset.field);
        this.filterCol = colDef;
        this.populateFilterModal();
        this.filterModalOpen=true;
    }
    
    handleHeaderSort(event){
        const colDef = this.columns.find((element) => element.fieldName === event.target.dataset.field);
        if (this.sortBy!=colDef.fieldName){
            this.sortBy = colDef.fieldName;
            this.sortDirection="asc";
        } else {
            this.sortDirection=(this.sortDirection=="asc")?"desc":"asc";
        }
        this.initializeColumns();
        colDef["sortIcon"] = (this.sortDirection=="asc")?"utility:arrowup":"utility:arrowdown";
        this.sortData();
    }


    populateFilterModal(){
        this.filterModalTitle='Filter for ' + this.filterCol.label;
        this.filterModalList=[];
        this.filterMap[this.filterCol.fieldName].forEach(item => {
            this.filterModalList.push({value:item, label:item});
        });
        this.filterModalListSelected=this.filterMapSelected[this.filterCol.fieldName];
    }
    
    handleFilterChange(event){
        const changeValue = event.detail.value;
        this.filterModalListSelected = changeValue;
    }

    get modalBackdropStyle(){
        return "slds-backdrop slds-backdrop_" + (this.filterModalOpen?'open':'closed');
    }

    get modalStyle(){
        return "slds-modal slds-modal_small slds-fade-in-" +  (this.filterModalOpen?'open':'closed');
    }

    arrayRemove(items, value){
        while (items.indexOf(value) !== -1) {
            items.splice(items.indexOf(value), 1);
          }
    }
    //apply filters, add filter indicator to column.
    handleFilterDone(){
        if (this.modalIsFilter){
            if (this.filterModalListSelected.includes("[Any value]")){
                this.filterModalListSelected = [];
            }
            if (this.filterModalListSelected.includes("[No value]")){
                this.filterModalListSelected.push('');
                this.filterModalListSelected.push(null);
                this.filterModalListSelected.push(undefined);
            } else {
                this.arrayRemove(this.filterModalListSelected, '');
                this.arrayRemove(this.filterModalListSelected, null);
                this.arrayRemove(this.filterModalListSelected, undefined);
            }
            
            this.filterMapSelected[this.filterCol.fieldName]=this.filterModalListSelected;
            let cList = [...this.columns];//copy the columns - direct update won't refresh the grid
            let col = cList.filter(c => {
                return c.fieldName === this.filterCol.fieldName;
            });
            col[0].label = col[0].label.replace("*","");
            col[0].label += (this.filterModalListSelected.length>0)?"*":"";
            this.columns = cList;
            
            this.filterModalTitle='Filter';
            this.filterModalList=[];
            this.filterItems();
            this.filterModalOpen=false;
        } else {
            this.filterModalOpen=false;
        }
        
    }

    //regenerate filtered case list based on selected filters
    filterItems(){
        let localCaseList = [];
        let keyset = Object.keys(this.filterMapSelected);
        let validkeyset = [];
        keyset.forEach(k => {
            if (this.filterMapSelected[k].length>0){
                validkeyset.push(k);
            }
        });
        if (validkeyset.length>0  || this.searchTerm){
            this.caseList.forEach(c => {
                let bAdd=true;
                if (this.searchTerm){
                    var bSearchHit = false;
                    this.columns.forEach(col => {
                        if (col["searchable"]==true){
                            //console.log(col.fieldName, c[col.fieldName]);
                            if (c[col.fieldName]!=undefined && c[col.fieldName].toLowerCase().includes(this.searchTerm.toLowerCase())){
                                bSearchHit=true;
                            }
                        }
                    });
                    if (!bSearchHit){
                        bAdd=false;
                        return;
                    }
                } 
                validkeyset.forEach(k => {
                    let valids = this.filterMapSelected[k];
                    if (bAdd && valids.length>0 && !valids.includes(c[k])){
                        bAdd=false;
                        return;
                    }
                });
                
                if (bAdd){
                    localCaseList.push(c);
                }
            });
        } else {
            localCaseList = this.caseList
        }

        this.setFilteredCaseList(localCaseList);
    }

    handleResetSelectedFilters(){
        this.columns.forEach(col => {
            if (col.hasOwnProperty("actions")){
                this.filterMapSelected[col.fieldName]=new Array();
            }
        });

        let cList = [...this.columns];//copy the columns - direct update won't refresh the grid
        cList.forEach(c => {
            c.label = c.label.replace("*","");
        });
        this.columns = cList;
        this.filterItems();
        if (this.sortBy!=null){
            this.sortData();
        }
        
    }


    sortData() {
        let workingData = [...this.filteredCaseList];
        // Return the value stored in the field
        let keyValue = (a) => {
            return a[this.sortBy];
        };
        
        let isReverse = this.sortDirection === 'asc' ? 1: -1;
        // sorting data
        workingData.sort((x, y) => {
            x = keyValue(x) ? keyValue(x) : ''; // handling null values
            y = keyValue(y) ? keyValue(y) : '';
            // sorting values based on direction
            return isReverse * ((x > y) - (y > x));
        });
        this.setFilteredCaseList(workingData);
    }
    
    get filterMapDescription(){
        let filterString = '';
        const fms = this.filterMapSelected;
        if(fms!=null){
            const cols = this.columns;
            Object.keys(fms).forEach(function(keyval) {
                const key = keyval.replace('not_','')
                if (fms[key] && fms[key].length>0) {
                    let col = cols.filter(c => {
                        return c.fieldName === key;
                    });
                    if (col[0]){
                        filterString+=col[0].label.replace('*','') + ' [' + fms[key].filter(Boolean).join(', ')+ '] ';
                    } else {
                        console.log('Not a described filter: ' + fms[key]);
                    }
                }
                
            });
        }
        return (filterString!='')?('Filters: '+filterString):'';
    }

    get hasFilter(){
        let hf=false;
        const fms = this.filterMapSelected;
        if(fms!=null){
            Object.keys(fms).forEach(function(key) {
                if (fms[key] && fms[key].length>0) {
                    hf=true;
                }
            });
        }
        
        return hf;
    }

    get filteredListSize(){
        return (this.filteredCaseList)?this.filteredCaseList.length:0;
    }

    get listSizeStatus(){
        let status = 'No Data';
        if (this.caseList){
            status = '';
            if (this.hasFilter || this.searchTerm){
                status = 'Showing ' + this.filteredListSize + ' of ';
            }
            status += this.caseList.length + ' cases';
        }
        return status;
    }
    get lastRefreshed(){
        let refreshed = ''
        if (this.pageData && this.pageData.lastRefresh){
            refreshed = this.pageData.lastRefresh;
        }
        return refreshed;
    }

    setCookie(name, value) {
        document.cookie = name + "=" + value + "; path=/";
    }
    getCookie(name) {
        const cookie=document.cookie.split('; ').find(row => row.startsWith(`${name}=`))?.split('=')[1];
      return (cookie=='null')?null:cookie;
    }

    handleSearchKeyUp(event) {
        const isEnterKey = event.keyCode === 13;
        if (isEnterKey) {
            this.searchTerm = event.target.value;
            this.filterItems();
        }
    }
    handleSearchClear(event){
        this.searchTerm=null;
        this.filterItems();
    }
    
    handleCaseSelection(event){
        this.selectedCase = this.caseList.find((element) => element.caseId === event.detail);
        this.modalIsFilter=false;
        this.filterModalOpen=true;
        
    }
    handleCaseReturn(event){

        if (event.detail!="Cancel"){

            var newCaseList = [];
            var thisCase={};
            for (var c in this.caseList){
                
                if (this.caseList[c].caseId===event.detail.caseId){
                    thisCase = this.caseList[c];
                    thisCase.version+=1;
                    thisCase.reviewed='Yes';
                    if (this.pageData.firstReviewedCase==null){
                        caseReviewCheck({reviewId:this.recordId, caseId:thisCase.caseId}).then(result=>{
                            console.log('Sent caseReviewCheck');
                        }).catch(error =>{
                            console.log('Error: ' + this.error);
                        });
                    }
                    console.log(thisCase);
                    for (var k in event.detail.changes){
                        console.log(k,event.detail.changes[k]);

                        //blending wrapper based data with LDS might not have been the best plan.
                        switch (k) {
                            case "Queue_Review_Notes__c":
                                thisCase['reviewNotes'] = event.detail.changes[k];
                                thisCase['shortReview'] = (event.detail.changes[k].length>100)?(event.detail.changes[k].substring(0,200)+'...'):event.detail.changes[k];
                                break;
                            case "Impact__c":
                                thisCase['Impact'] = event.detail.changes[k];
                                break;
                            case "Due_Date__c":
                                thisCase['dueDate'] = event.detail.changes[k];
                                break;
                            case "LOE_Estimate__c":
                                thisCase['LOE'] = event.detail.changes[k];
                                break;
                            default:
                                thisCase[k]=event.detail.changes[k];
                                break;
                        }
                        

                    }
                }
                newCaseList.push(Object.assign({}, this.caseList[c])); 
            }
            this.caseList = newCaseList;
            this.refreshFilterMap();
            this.filterItems();
            this.sortData();
        }
        this.filterModalOpen=false;
    }
}