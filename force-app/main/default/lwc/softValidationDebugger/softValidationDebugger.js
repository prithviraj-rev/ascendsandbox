import { api, track, LightningElement } from 'lwc';
import evaluateRule from '@salesforce/apex/SoftValidationDebuggerController.evaluateRule';

const MSG_TYPE_PARAMS = {
  'Error': {
    cssClasses: 'notify-alert-container',
    iconName: 'utility:error',
    iconAlternativeText: 'Error',
    iconTitle: 'Error',
    iconVariant: 'inverse',
    backgroundColor: '#ea001e'
  },
  'Warning': {
    cssClasses: 'notify-alert-container',
    iconName: 'utility:warning',
    iconAlternativeText: 'Warning',
    iconTitle: 'Warning',
    iconVariant: '',
    backgroundColor: '#fe9339'
  },
  'Success': {
    cssClasses: 'notify-alert-container',
    iconName: 'utility:success',
    iconAlternativeText: 'Success',
    iconTitle: 'Success',
    iconVariant: 'inverse',
    backgroundColor: '#2e844a'
  },
  'Info': {
    cssClasses: 'notify-alert-container',
    iconName: 'utility:info_alt',
    iconAlternativeText: 'Info',
    iconTitle: 'Info',
    iconVariant: 'inverse',
    backgroundColor: '#706e6b'
  }
};

export default class SoftValidationDebugger extends LightningElement {
  @api recordId;
  
  asyncJobsWorking = false;
  jobs = [];
  
  dataSourceRecordId = '';
  messageToShow = null;
  ruleEvalData = null;
  @track criteriaDebugData = [];
  @track messageMergeFieldsDebugData = [];
  
  hasMessageToShow = false;
  hasRuleEvalData = false;
  
  @track pageState = {
    isQualifiedForEvaluationShow: false,
    isFilterLogicLogsShow: false
  };
  
  isQualifiedForEvaluationShowOnClick(){
    this.pageState.isQualifiedForEvaluationShow = !this.pageState.isQualifiedForEvaluationShow;
  }
  
  isFilterLogicLogsShowOnClick(){
    this.pageState.isFilterLogicLogsShow = !this.pageState.isFilterLogicLogsShow;
  }
  
  get isQualifiedForEvaluationExpectedObj(){
    return this.ruleEvalData.ruleRecord.ObjectAPIName__c || 'N/A';
  }
  
  get isQualifiedForEvaluationActualObj(){
    return this.ruleEvalData.sObjectName || 'N/A';
  }
  
  get isQualifiedForEvaluationObjIsQualified(){
    let isQualified = false;
    
    if (typeof this.ruleEvalData.ruleRecord.ObjectAPIName__c === 'string' && typeof this.ruleEvalData.sObjectName === 'string'){
      let expectedObjNameLower = this.ruleEvalData.ruleRecord.ObjectAPIName__c.toLowerCase();
      let actualObjNameLower = this.ruleEvalData.sObjectName.toLowerCase();
      
      isQualified = (expectedObjNameLower === actualObjNameLower);
    }
    
    return isQualified;
  }
  
  get isQualifiedForEvaluationExpectedRT(){
    return this.ruleEvalData.ruleRecord.RecordTypeDevName__c || 'ANY';
  }
  
  get isQualifiedForEvaluationActualRT(){
    return this.ruleEvalData.recordRTDevName || 'N/A';
  }
  
  get isQualifiedForEvaluationRTIsQualified(){
    if (!this.ruleEvalData.ruleRecord.RecordTypeDevName__c) return true;
    
    let isQualified = false;
    
    if (typeof this.ruleEvalData.ruleRecord.RecordTypeDevName__c === 'string' && typeof this.ruleEvalData.recordRTDevName === 'string'){
      let expectedRTNameLower = this.ruleEvalData.ruleRecord.ObjectAPIName__c.toLowerCase();
      let actualRTNameLower = this.ruleEvalData.sObjectName.toLowerCase();
      
      isQualified = (expectedRTNameLower === actualRTNameLower);
    }
    
    return isQualified;
  }
  
  get isQualifiedForEvaluationExpectedBU(){
    return this.ruleEvalData.ruleRecord.BusinessUnit__c || 'ANY';
  }
  
  get isQualifiedForEvaluationActualBU(){
    return this.ruleEvalData.userBusinessUnit || 'N/A';
  }
  
  get isQualifiedForEvaluationBUIsQualified(){
    if (!this.ruleEvalData.ruleRecord.BusinessUnit__c) return true;
    
    let isQualified = false;
    
    if (typeof this.ruleEvalData.ruleRecord.BusinessUnit__c === 'string' && typeof this.ruleEvalData.userBusinessUnit === 'string'){
      let expectedBUNameLower = this.ruleEvalData.ruleRecord.BusinessUnit__c.toLowerCase();
      let actualBUNameLower = this.ruleEvalData.userBusinessUnit.toLowerCase();
      
      isQualified = (expectedBUNameLower === actualBUNameLower);
    }
    
    return isQualified;
  }
  
  criterionShowDetailsOnClick(e){
    let targetName = e.target.getAttribute('data-name');
    
    if (targetName){
      let targetNameParts = targetName.split('-');
      let index = parseInt(targetNameParts[0], 10);
      
      if (targetNameParts.length > 1){
        let param2 = targetNameParts[1];
        
        if (param2 === 'left' || param2 === 'right'){
          this.criteriaDebugData[index].evaluation[param2 + 'Exp']._showDetails = !this.criteriaDebugData[index].evaluation[param2 + 'Exp']._showDetails;
        }
        else if (param2 === 'logs'){
          this.criteriaDebugData[index].evaluation._showLogs = !this.criteriaDebugData[index].evaluation._showLogs;
        }
      }
      else{
        this.criteriaDebugData[index]._showDetails = !this.criteriaDebugData[index]._showDetails;
      }
    }
  }
  
  messageMergeFieldShowDetailsOnClick(e){
    let targetName = e.target.getAttribute('data-name');
    
    if (targetName){
      let index = parseInt(targetName, 10);
      this.messageMergeFieldsDebugData[index].evaluation._showDetails = !this.messageMergeFieldsDebugData[index].evaluation._showDetails;
    }
  }
  
  connectedCallback() {
    //do nothing
  }
  
  evaluateOnClick(){
    this.reset();
    let element = this.template.querySelector("[data-id='dataSourceRecordId']");
    
    if (element){
      this.dataSourceRecordId = element.value;
      if (typeof this.dataSourceRecordId !== 'string' || this.dataSourceRecordId.length === 0) return;
  
      const promise = evaluateRule({ params: {ruleId: this.recordId, recordId: this.dataSourceRecordId} })
        .then(this.actionHandler.bind(this, this.evaluateRuleActionHandler))
        .catch(this.actionErrorHandler.bind(this, this.evaluateRuleActionHandler));
  
      this.trackAsyncJob(promise);
    }
  }
  
  evaluateRuleActionHandler({ success, data, errorMessage, errorDetails }) {
    if (success) {
      //console.log('data', data);
      let criterionValueByIndex = {};
      this.ruleEvalData = JSON.parse(data);
  
      this.ruleEvalData._success = (this.ruleEvalData.successParse === true && this.ruleEvalData.successEvaluate === true && this.ruleEvalData.messageSuccessParse === true && this.ruleEvalData.messageSuccessEvaluate === true);
      
      if (this.ruleEvalData.successParse === true){
        if (this.ruleEvalData.isQualifiedForEvaluation === false) this.pageState.isQualifiedForEvaluationShow = true;
        
        this.ruleEvalData._hasDebugData = (typeof this.ruleEvalData.debugData === 'object' && this.ruleEvalData.debugData !== null);
        this.ruleEvalData._hasCriteria = false;
  
        if (this.ruleEvalData._hasDebugData){
          if (Array.isArray(this.ruleEvalData.debugData.criteria)){
            this.ruleEvalData._hasCriteria = (this.ruleEvalData.debugData.criteria.length > 0);
      
            for (let i = 0; i < this.ruleEvalData.debugData.criteria.length; i++){
              let criterionDebugData = this.ruleEvalData.debugData.criteria[i];
        
              criterionDebugData._name = i + '';
              criterionDebugData._showDetails = false;
              criterionDebugData._hasEvaluationData = (typeof criterionDebugData.evaluation === 'object' && criterionDebugData.evaluation !== null);
        
              if (criterionDebugData._hasEvaluationData){
                populateExpressionFieldsForRenderer(criterionDebugData.evaluation.leftExp, i + '-left');
                populateExpressionFieldsForRenderer(criterionDebugData.evaluation.rightExp, i + '-right');
  
                criterionDebugData.evaluation._hasResult = (typeof criterionDebugData.evaluation.result === 'boolean');
                
                criterionDebugData.evaluation._logsName = i + '-logs';
                criterionDebugData.evaluation._hasLogs = false;
                criterionDebugData.evaluation._showLogs = false;
          
                if (Array.isArray(criterionDebugData.evaluation.logs)){
                  criterionDebugData.evaluation._logItems = generateLogItems(criterionDebugData.evaluation.logs);
                  criterionDebugData.evaluation._hasLogs = (criterionDebugData.evaluation._logItems.length > 0);
                }
          
                criterionValueByIndex[(i + 1) + ''] = (criterionDebugData.evaluation.result === true ? 'TRUE' : 'FALSE');
              }
        
              this.criteriaDebugData.push(criterionDebugData);
            }
          }
  
          this.ruleEvalData._hasFilterLogicExp = (typeof this.ruleEvalData.ruleRecord.FilterLogic__c === 'string' && this.ruleEvalData.ruleRecord.FilterLogic__c.length > 0);
          this.ruleEvalData._filterLogicExp = (this.ruleEvalData.ruleRecord.FilterLogic__c || 'N/A - AND is used');
          this.ruleEvalData._hasFilterLogic = (typeof this.ruleEvalData.debugData.filterLogic === 'object' && this.ruleEvalData.debugData.filterLogic !== null);
          this.ruleEvalData._hasFilterLogicDebugData = false;
    
          if (this.ruleEvalData._hasFilterLogic){
            this.ruleEvalData._hasFilterLogicDebugData = (typeof this.ruleEvalData.debugData.filterLogic.evaluation === 'object' && this.ruleEvalData.debugData.filterLogic.evaluation !== null);
      
            if (this.ruleEvalData._hasFilterLogicDebugData){
              this.ruleEvalData.debugData.filterLogic._hasResult = (typeof this.ruleEvalData.debugData.filterLogic.evaluation.result === 'boolean');
              this.ruleEvalData.debugData.filterLogic._hasLogs = false;
        
              if (Array.isArray(this.ruleEvalData.debugData.filterLogic.evaluation.logs)){
                this.ruleEvalData.debugData.filterLogic._logItems = generateLogItems(this.ruleEvalData.debugData.filterLogic.evaluation.logs);
                this.ruleEvalData.debugData.filterLogic._hasLogs = (this.ruleEvalData.debugData.filterLogic._logItems.length > 0);
              }
            }
          }
  
          this.ruleEvalData._hasMessageMergeFields = false;
          if (Array.isArray(this.ruleEvalData.debugData.messageMergeFields)){
            this.ruleEvalData._hasMessageMergeFields = (this.ruleEvalData.debugData.messageMergeFields.length > 0);
    
            for (let i = 0; i < this.ruleEvalData.debugData.messageMergeFields.length; i++){
              let mergeFieldDebugData = this.ruleEvalData.debugData.messageMergeFields[i];
      
              mergeFieldDebugData._name = i + '';
              mergeFieldDebugData._showDetails = false;
              mergeFieldDebugData._hasEvaluationData = (typeof mergeFieldDebugData.evaluation === 'object' && mergeFieldDebugData.evaluation !== null);
      
              if (mergeFieldDebugData._hasEvaluationData){
                populateExpressionFieldsForRenderer(mergeFieldDebugData.evaluation, i + '', '#error');
              }
      
              this.messageMergeFieldsDebugData.push(mergeFieldDebugData);
            }
          }
          
          if (this.ruleEvalData.isQualified === true && this.ruleEvalData.ruleRecord.MessageType__c && this.ruleEvalData.ruleMessage){
            this.messageToShow = this.getRuleAlertMessage({
              ruleBodyHeight: this.ruleEvalData.ruleRecord.MessageMaxHeight__c,
              ruleType: this.ruleEvalData.ruleRecord.MessageType__c,
              ruleMsg: this.ruleEvalData.ruleMessage,
              ruleCustomSettings: (typeof this.ruleEvalData.ruleRecord.MessageCustomSettings__c === 'string' ? JSON.parse(this.ruleEvalData.ruleRecord.MessageCustomSettings__c) : {})
            });
          }
        }
      }
      
      if (this.ruleEvalData.successParse === false || this.ruleEvalData.successEvaluate === false || this.ruleEvalData.messageSuccessParse === false || this.ruleEvalData.messageSuccessEvaluate === false){
        this.messageToShow = this.getErrorAlertMessage(this.ruleEvalData.errorMessage, this.ruleEvalData.errorDetails);
      }
    }
    else {
      this.messageToShow = this.getErrorAlertMessage(errorMessage, errorDetails);
    }
    
    this.hasMessageToShow = (typeof this.messageToShow === 'object' && this.messageToShow !== null);
    this.hasRuleEvalData = (this.ruleEvalData !== null);
    
    function populateExpressionFieldsForRenderer(exp, name, errorValue){
      exp._name = name;
      exp._showDetails = false;
      exp._resultValueComposite = '?';
      exp._resultValue = '?';
      exp._resultType = '?';
      exp._resultIsError = false;
      exp._resultError = '';
  
      if (typeof exp.result === 'object' && exp.result !== null){
        exp._resultValue = exp.result.value;
        exp._resultType = exp.result.type;
    
        if (exp._resultValue === null){
          exp._resultValue = 'NULL'
          exp._resultType = 'NULL';
          exp._resultValueComposite = 'NULL';
        }
        else{
          exp._resultValueComposite = '[' + exp._resultValue + ']:' + exp._resultType;
        }
      }
      else if (typeof exp.result === 'string'){
        exp._resultIsError = true;
        exp._resultError = exp.result;
        
        if (typeof errorValue === 'string'){
          exp._resultValueComposite = errorValue;
          exp._resultValue = errorValue;
        }
      }
  
      exp._hasLogs = false;
      if (Array.isArray(exp.logs)){
        exp._logItems = generateLogItems(exp.logs);
        exp._hasLogs = (exp._logItems.length > 0);
      }
    }
    
    function generateLogItems(logs){
      let logItems = [];
  
      for (let i = 0; i < logs.length; i++){
        logItems.push({
          index: i,
          cssClasses: 'msg-line' + (i === 0 ? ' first' : ''),
          logStr: (i + 1) + '. ' + logs[i]
        });
      }
      
      return logItems;
    }
  }
  
  getRuleAlertMessage(evalData){
    let ruleAlertMessage;
    
    if (evalData){
      let ruleBodyHeight = (typeof evalData.ruleBodyHeight === 'number' ? evalData.ruleBodyHeight : 0);
  
      if (evalData.ruleType === 'Custom'){
        ruleAlertMessage = {
          type: evalData.ruleType,
          cssClasses: 'notify-alert-container first',
          cssStyles: (typeof evalData.ruleCustomSettings.backgroundColor === 'string' ? 'background-color:' + evalData.ruleCustomSettings.backgroundColor + ';' : ''),
          iconName: (evalData.ruleCustomSettings.iconName ? 'utility:' + evalData.ruleCustomSettings.iconName : ''),
          iconAlternativeText: '',
          iconTitle: '',
          iconVariant: (evalData.ruleCustomSettings.iconVariant || ''),
          msgBodyCssStyles: (ruleBodyHeight > 0 ? 'max-height:' + ruleBodyHeight + 'px;' : ''),
          msgRichText: evalData.ruleMsg
        };
      }
      else{
        let alertMsgParams = MSG_TYPE_PARAMS[evalData.ruleType];
    
        if (alertMsgParams){
          ruleAlertMessage = {
            type: evalData.ruleType,
            cssClasses: alertMsgParams.cssClasses + ' first',
            cssStyles: 'background-color:' + alertMsgParams.backgroundColor + ';',
            iconName: alertMsgParams.iconName,
            iconAlternativeText: alertMsgParams.iconAlternativeText,
            iconTitle: alertMsgParams.iconTitle,
            iconVariant: alertMsgParams.iconVariant,
            msgBodyCssStyles: (ruleBodyHeight > 0 ? 'max-height:' + ruleBodyHeight + 'px;' : ''),
            msgRichText: evalData.ruleMsg
          };
        }
      }
    }
  
    return ruleAlertMessage;
  }
  
  getErrorAlertMessage(errorMessage, errorDetails){
    let errorMessageTemplateGeneric = '<p><b style="font-size: 12px; color: rgb(255, 255, 255);">Error</b><span style="color: rgb(255, 255, 255);">: {errMsg}</span></p>';
    let errorDetailsTemplate = '<p><br></p><p><span style="color: rgb(255, 255, 255);">{errDetails}</span></p>';
    let errorAlertMessage;
    
    if (typeof errorMessage === 'string' && errorMessage.length > 0){
      let errorMessageHTML;
  
      errorMessageHTML = errorMessageTemplateGeneric.replace('{errMsg}', this.escapeHTML(errorMessage));
      
      if (typeof errorDetails === 'string' && errorDetails.length > 0 && errorDetails !== '()'){
        errorMessageHTML += errorDetailsTemplate.replace('{errDetails}', this.escapeHTML(errorDetails));
      }
  
      let infoMsgType = MSG_TYPE_PARAMS['Error'];
      
      errorAlertMessage = {
        type: 'Error',
        cssClasses: infoMsgType.cssClasses + ' first',
        cssStyles: 'background-color:' + infoMsgType.backgroundColor + ';',
        iconName: infoMsgType.iconName,
        iconAlternativeText: infoMsgType.iconAlternativeText,
        iconTitle: infoMsgType.iconTitle,
        iconVariant: infoMsgType.iconVariant,
        msgBodyCssStyles: '',
        msgRichText: errorMessageHTML
      };
    }
    
    return errorAlertMessage;
  }
  
  reset(){
    this.hasMessageToShow = false;
    this.messageToShow = null;
    this.hasRuleEvalData = false;
    this.ruleEvalData = null;
    this.pageState.isQualifiedForEvaluationShow = false;
    this.criteriaDebugData.length = 0;
    this.messageMergeFieldsDebugData.length = 0;
  }
  
  actionHandler(doneCallback, resp, error) {
    let _error = '';
    let _errorDetails = '';
    let result = { success: true };
    
    if (resp) {
      if (resp.success || resp.success === undefined) {
        result.data = (typeof resp.result === 'undefined' ? resp : resp.result);
      }
      else {
        _error = resp.message;
        _errorDetails = (resp.technicalData ? (resp.technicalData.stackTrace || '') : '');
      }
    }
    else {
      if (typeof error === 'object' && error !== null){
        if (typeof error.body === 'object' && error.body !== null){
          _error = (typeof error.body.exceptionType === 'string' ? error.body.exceptionType + ': ' : '') + (typeof error.body.message === 'string' ? error.body.message : '');
          _errorDetails = (typeof error.body.stackTrace === 'string' ? error.body.stackTrace : '');
        }
        else if (typeof error.message === 'string'){
          _error = error.message;
        }
      }
      else if (typeof error === 'string'){
        _error = error;
      }
      
      if (!_error) _error = 'Internal Server Error';
    }
    
    if (_error) {
      Object.assign(result, { success: false, errorMessage: _error, errorDetails: _errorDetails });
    }
    
    doneCallback.call(this, result);
  }
  
  actionErrorHandler(doneCallback, error) {
    this.actionHandler(doneCallback, null, error);
  }
  
  trackAsyncJob(promise) {
    if (Array.isArray(promise))
      this.jobs = [...this.jobs, ...promise];
    else if (promise)
      this.jobs.push(promise);
    
    if (!this.trackerLocked) {
      this.trackerLocked = true;
      this.asyncJobsWorking = true;
      
      Promise.all(this.jobs).finally(() => {
        this.trackerLocked = false;
        if (this.jobs.length) {
          this.trackAsyncJob();
        }
        else {
          this.asyncJobsWorking = false;
        }
      });
      
      this.jobs = [];
    }
  }
  
  escapeHTML(str){
    if (typeof str !== 'string') return str;
    
    return str.replace(
      /[&<>'"]/g,
      tag =>
        ({
          '&': '&amp;',
          '<': '&lt;',
          '>': '&gt;',
          "'": '&#39;',
          '"': '&quot;'
        }[tag] || tag)
    );
  }
}