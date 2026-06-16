import { LightningElement, api } from 'lwc';
import makeChatter from '@salesforce/apex/caseViewHelper.makeChatter';


export default class CaseViewEdit extends LightningElement {
    @api caseRecord={};
    @api editFields={};
    previousReview;
    allFieldsLoaded=false;
    caseNumber;
    statusOptions=[{label:'', value:''}, {label:'On Hold', value:'On Hold'}, {label:'Backlog', value:'BackLog'}];

    get hasCaseRecord(){
        return (this.caseRecord!=null);
    }
    get cardTitle(){
        return (this.caseRecord)?(this.caseRecord.CaseNumber + ': ' + this.caseRecord.Subject):"";
    }
    
    get ownerColorStyle(){
        return (this.caseRecord)?("color-bg color-"+this.caseRecord.ownerSequence):"";
    }

    get ownerInitials(){
        return (this.caseRecord)?this.caseRecord.ownerInitials:"";
    }

    get priorityIcon(){
        return (this.caseRecord && this.caseRecord.Priority=="High")?"utility:arrowup":"";
    }
    get highPriority(){
        return (this.caseRecord && this.caseRecord.Priority=="High");
    }
    get isReviewed(){
        return (this.caseRecord.reviewed=='Yes');
    }
    connectedCallback(){
        console.log('Connected Callback');
        this.reset();
    }

    reset(){
        this.previousReview = this.caseRecord.wrappedCase['Current_Review_Notes__c'];
        this.allFieldsLoaded = false;
    }

    renderedCallback(){
        if (this.CaseNumber!=this.caseRecord.CaseNumber){
            this.reset();
        }
        if (this.allFieldsLoaded==false){
            var crn = this.template.querySelector('lightning-input-field[data-name="Current_Review_Notes__c"]');
            if (crn){
                crn.value='';
                this.allFieldsLoaded = true;
            }
        }
        

    }

    handleSubmit(event){
        console.log('handleSubmit');
        var changed={};
        const inputFields = this.template.querySelectorAll('lightning-input-field');
        const statusChange = this.template.querySelector("lightning-select[data-name='changeStatus']");
        var notesPrepend = '';
        if (inputFields) {
            inputFields.forEach(field => {
                if (field.fieldName=='Status' && statusChange && statusChange.value!=""){
                    changed["Status"] = statusChange.value;
                    field.value = statusChange.value;
                }
                //don't pass changed value for Current review if it's blank.
                if (field.fieldName=='Current_Review_Notes__c' && field.value!='' && this.caseRecord.wrappedCase[field.fieldName]!=field.value){
                    console.log('Notes handling');
                    changed[field.fieldName] = field.value;
                    notesPrepend = (new Date()).toLocaleDateString('en-US') + ' - ' + field.value + '\n';
                    console.log(notesPrepend);
                    makeChatter({caseId:this.caseRecord.caseId, chatter:field.value}).then(result=>{
                        console.log('Chattered');
                    }).catch(error =>{
                        console.log('Error: ' + this.error);
                        
                    });
                } else if (this.caseRecord.wrappedCase[field.fieldName]!=field.value){
                    changed[field.fieldName] = field.value;
                }
            });
        }
        if (notesPrepend!=''){
            const qrn = this.template.querySelector('lightning-input-field[data-name="Queue_Review_Notes__c"]');
            qrn.value = notesPrepend + ((qrn.value!=null)?qrn.value:'');
            changed["Queue_Review_Notes__c"] = qrn.value;
        }
        console.log('sending return');
        const returnCase = {caseId:this.caseRecord.caseId, changes:changed}
        const returnEvent = new CustomEvent("return", { detail: returnCase });
        this.dispatchEvent(returnEvent);

        this.template.querySelector('lightning-record-edit-form').submit(event.detail.fields);
        console.log('Return case', returnCase);
    }

    sendSubmit(event) {
        //event.preventDefault(); 
        this.fields = event.detail.fields;
        console.log('sendSubmit(override)');
    }
    
    handleCancel(event){
        const returnEvent = new CustomEvent("return", { detail: "Cancel" });
        this.dispatchEvent(returnEvent);

    }
    handleReset(event) {
        const inputFields = this.template.querySelectorAll('lightning-input-field');
        if (inputFields) {
            inputFields.forEach(field => {
                field.reset();
            });
        }
     }
}