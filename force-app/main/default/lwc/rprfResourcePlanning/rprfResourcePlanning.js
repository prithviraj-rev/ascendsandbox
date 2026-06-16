import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import { Utilities } from 'c/utilities';

import {
    IsConsoleNavigation,
    EnclosingTabId,
    getFocusedTabInfo,
    setTabLabel,
    setTabIcon
} from 'lightning/platformWorkspaceApi';

export default class rprfResourcePlanning extends NavigationMixin(LightningElement) 
{
    CURRENT_DATE = Utilities.getLocalDateISOString(new Date());

    @track configuration = { canManageResources: true };
    @track weekConfiguration = {};

    initialized;
    renderTrigger = 0;
    showSpinner = false;
    showModalSpinner = false;
    showEditProjectedHoursModal = false;
    editedProjectedHours = { projectedHours: '', actualHours: '' };
    assignments = [];
    daysOff = {};
    allDatesOfCurrentWeek = [];
    selectedDate = this.CURRENT_DATE;
    selectedResourceId = null;
    selectedProjectId = null;
    linksTarget = '_blank';

    get columns() {
        return this.getColumns();
    }

    get secondRowHeaderColumns() {
        return this.getColumns();
    }

    get thirdRowHeaderColumns() {
        return this.getColumns();
    }

    get fourthRowHeaderColumns() {
        return this.getColumns();
    }

    get reviewCompleteDates() {
        const startDate = this.convertDateToLocaleString(this.allDatesOfCurrentWeek[0]);
        const endDate = this.convertDateToLocaleString(this.allDatesOfCurrentWeek[this.allDatesOfCurrentWeek.length - 1]);
        return this.allDatesOfCurrentWeek.length === 0 ? '' : `${startDate} - ${endDate}`;
    }

    get isCurrentWeek() {
        return this.allDatesOfCurrentWeek.includes(this.CURRENT_DATE);
    }

    get isFutureWeek() {
        const datesOfCurrentWeek = Array.from(Array(7).keys()).map((idx) => {const d = Utilities.getLocalDateFromISOString(this.CURRENT_DATE); d.setDate(d.getDate() - d.getDay() + idx); return Utilities.getLocalDateISOString(d); });
        return Utilities.getLocalDateFromISOString(datesOfCurrentWeek[datesOfCurrentWeek.length - 1]) < Utilities.getLocalDateFromISOString(this.allDatesOfCurrentWeek[0]);
    }

    get isEmptyAssignments() {
        return this.assignments.length === 0;
    }

    get canSubmitForecast() {
        const now = Utilities.getLocalDateFromISOString(this.CURRENT_DATE);
        const selectedDate = Utilities.getLocalDateFromISOString(this.selectedDate);
        const startDate = new Date(new Date(now).setDate(now.getDate() - now.getDay() + 5));
        const endDate = new Date(new Date(now).setDate(now.getDate() - now.getDay() + 12));
        const allowedByDate = startDate <= selectedDate && endDate > selectedDate;

        return this.selectedResourceId && !this.weekConfiguration?.hasSubmitedForecast && allowedByDate;
    }

    get submitForecastButtonLabel() {
        const now = Utilities.getLocalDateFromISOString(this.CURRENT_DATE);
        const selectedDate = Utilities.getLocalDateFromISOString(this.selectedDate);
        const startOfThisWeek = new Date(new Date(now).setDate(now.getDate() - now.getDay()));
        const endOfThisWeek = new Date(new Date(now).setDate(now.getDate() - now.getDay() + 7));
        return startOfThisWeek <= selectedDate && endOfThisWeek > selectedDate ? 'Submit Next Week Forecast' : 'Submit Forecast';
    }

    get saveProjectedHoursDisabled() { 
        let projectedHoursInput = this.template.querySelector(".projected-hours-input");
        return !(this.editedProjectedHours && this.editedProjectedHours.canSave && projectedHoursInput?.validity?.valid) || this.showModalSpinner;
    }
    

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            this.selectedProjectId = currentPageReference.state?.c__projectId || null;
            this.selectedResourceId = currentPageReference.state?.c__resourceId || null;
            if(currentPageReference.state?.c__date) this.selectedDate = currentPageReference.state?.c__date;
            this.initialized = false;
        }
    }

    @wire(IsConsoleNavigation) isConsoleNavigation;
    @wire(EnclosingTabId) subTabId;

    connectedCallback() {
        this.init();
    }

    renderedCallback() {
        if(!this.initialized) {
            this.connectedCallback();
        }
    }

    init() {
        this.initialized = true;

        this.updateConsoleTab();
        this.loadConfiguration(this.selectedResourceId, this.selectedProjectId).then(() => {
            this.refresh();
        });
    }

    refresh() {
        this.updateAllDatesOfCurrentWeek(this.selectedDate);
        this.getResourcePlanningData();
    }

    async updateConsoleTab() {
        if (!this.isConsoleNavigation) return;
        
        const { tabId } = await getFocusedTabInfo();
        setTabLabel(tabId, 'Resource Planning');
        setTabIcon(tabId, 'utility:groups', { iconAlt: 'Resource Planning' });

        if(this.subTabId) {
            setTabLabel(this.subTabId, 'Resource Planning');
            setTabIcon(this.subTabId, 'utility:groups', { iconAlt: 'Resource Planning' });
        }

        this.linksTarget = '_self';
    }

    getColumns() {
        return [
            { label: 'Assignment', index: Math.random(), fieldName: 'assignmentName', rowspan: 1, isFirstRow: false, className: 'assignment-name' },
            { label: 'Project', index: Math.random(), fieldName: 'projectName', rowspan: 1, isFirstRow: false, className: 'project-name' },
            { label: 'Start Date', index: Math.random(), fieldName: 'assignmentStartDate', rowspan: 1, isFirstRow: false, className: 'assignment-start-date' },
            { label: 'End Date', index: Math.random(), fieldName: 'assignmentEndDate', rowspan: 1, isFirstRow: false, className: 'assignment-end-date' },
            { label: 'Est Hours', index: Math.random(), fieldName: 'assignmentEstHours', rowspan: 1, isFirstRow: false, className: 'assignment-est-hours' },
            { label: 'Remaining Assignment Hours', index: Math.random(), fieldName: 'remainingAssignmentHours', rowspan: 1, isFirstRow: false, className: 'remaining-assignment-hours' },
            { label: 'Max Daily Hours', index: Math.random(), fieldName: 'assignmentMaxDailyHours', rowspan: 1, isFirstRow: false, className: 'assignment-max-daily-hours' },
            ...(this.allDatesOfCurrentWeek.map(fieldName => ({ label: this.convertDateToLocaleString(fieldName), index: Math.random(), fieldName, rowspan: 4, isFirstRow: true, className: 'assignment-hours-by-days' }))),
            { label: 'Total', index: Math.random(), fieldName: 'totalHours', rowspan: 1, isFirstRow: false, className: 'total-assignment-hours-by-days' },
            { label: 'Message on Assignment', index: Math.random(), fieldName: 'messageOnAssignment', rowspan: 1, isFirstRow: false, className: 'message-on-assignment' },
        ];
    }

    convertDateToLocaleString(date) {
        return (date ? Utilities.getLocalDateFromISOString(date) : new Date()).toLocaleDateString('en-US', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
        });
    }

    updateAllDatesOfCurrentWeek(date = this.selectedDate) {
        const currentDate = date ? Utilities.getLocalDateFromISOString(date) : new Date(); 
        const dayOfWeek = currentDate.toLocaleString('en-US', {weekday: 'short'});
        const dayNumber = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].indexOf(dayOfWeek);

        this.allDatesOfCurrentWeek = Array.from(Array(7).keys()).map((idx) => {
            const d = new Date(currentDate); 
            d.setDate(d.getDate() - dayNumber + idx); 
            return Utilities.getLocalDateISOString(d); 
        });
    }

    getResourcePlanningData(resourceId = this.selectedResourceId, projectId = this.selectedProjectId, fromDate = this.allDatesOfCurrentWeek[0], toDate = this.allDatesOfCurrentWeek[this.allDatesOfCurrentWeek.length - 1]) {
        this.showSpinner = true;
        this.daysOff = {};

        Promise.all([
            this.getWeekConfiguration(this.selectedDate, this.selectedResourceId),
            this.getAssignments(resourceId, projectId, fromDate, toDate),
            this.getDaysOffByResource(resourceId, fromDate, toDate),
            this.getDaysOffByProject(projectId, fromDate, toDate),
        ]).finally(() => {
            this.showSpinner = false;
        });
    }

    loadConfiguration(resourceId = null, projectId = null) {
        this.showSpinner = true;
        return Utilities.Apex.invoke(
            'RPRFResourcePlanningController',
            'getConfiguration',
            { resourceId, projectId }
        ).then((data) => {
            if(data.success === false && data.message) throw data.message;

            this.configuration = data.result;
            if(this.configuration.currentResource && !this.selectedResourceId) {
                this.selectedResourceId = this.configuration.currentResource.Id;
                this.configuration.resource = this.configuration.currentResource;
            }

            if (this.configuration?.project) this.template.querySelector('.project-abstract-lookup')?.setValue(this.configuration.project.Id, this.configuration.project.Name);
            if (this.configuration?.resource) this.template.querySelector('.resource-abstract-lookup')?.setValue(this.configuration.resource.Id, this.configuration.resource.Name);
            
            return data.result;
        }).catch((error) => {
            this.showSpinner = false;
            Utilities.Notification.handleError(error);
            return error;
        });
    }

    getWeekConfiguration(date, resourceId) {
        return Utilities.Apex.invoke(
            'RPRFResourcePlanningController',
            'getWeekConfiguration',
            { date, resourceId }
        ).then((data) => {
            if(data.success === false && data.message) throw data.message;

            this.weekConfiguration = data.result;
            return data.result;
        }).catch((error) => {
            Utilities.Notification.handleError(error);
            return error;
        });
    }

    async getAssignments(resourceId = null, projectId = null, fromDate, toDate) {
        let assignments = await Utilities.Apex.invoke(
            'RPRFResourcePlanningController',
            'getAssignments',
            { resourceId, projectId, fromDate, toDate }
        ).then((data) => {
            if(data.success === false && data.message) throw data.message;
            return data.result
        }).catch((error) => {
            Utilities.Notification.handleError(error);
            return error;
        });

        assignments = await this.getAssignmentsMessages(assignments);
        this.assignments = this.prepareAssignments(assignments);
    }

    getAssignmentsMessages(assignments) {
        let ids = assignments.map((record) => { return record.Id; });

        return Utilities.Apex.invoke(
            'RPRFResourcePlanningController',
            'getAssignmentsMessages',
            { ids }
        ).then((data) => {
            if(data.success === false && data.message) throw data.message;

            assignments.forEach(record => {
                record.message = data.result[record.Id];
            });

            return assignments;
        });
    }

    getDaysOffByResource(resourceId = null, fromDate, toDate) {
        return Utilities.Apex.invoke(
            'RPRFResourcePlanningController',
            'getDaysOffByResource',
            { resourceId, fromDate, toDate }
        ).then((data) => {
            if(data.success === false && data.message) throw data.message;

            let daysOffByResource = data.result;
            daysOffByResource['holidays'].forEach(item => {
                this.daysOff[item.Date__c] = item;
            });

            daysOffByResource['pto'].forEach(item => {
                this.daysOff[item.Date__c + item.Assignment__r?.Resource__c] = item;
            });
    
            return data.result;
        }).catch((error) => {
            Utilities.Notification.handleError(error);
            return error;
        });
    }

    getDaysOffByProject(projectId = null, fromDate, toDate) {
        return Utilities.Apex.invoke(
            'RPRFResourcePlanningController',
            'getDaysOffByProject',
            { projectId, fromDate, toDate }
        ).then((data) => {
            if(data.success === false && data.message) throw data.message;

            let daysOffByProject = data.result;

            daysOffByProject['holidays'].forEach(item => {
                this.daysOff[item.Date__c] = item;
            });

            daysOffByProject['pto'].forEach(item => {
                this.daysOff[item.Date__c + item.Assignment__r?.Resource__c] = item;
            });

            return data.result;
        }).catch((error) => {
            Utilities.Notification.handleError(error);
            return error;
        });
    }

    saveDailyAssignment(id, projectedHours) {
        this.showModalSpinner = true;

        let record = { Projected_Hours__c: projectedHours };
        if(id) record.Id = id;

        return Utilities.Apex.invoke(
            'RPRFResourcePlanningController',
            'saveDailyAssignment',
            { record }
        ).then((data) => {
            if(data.success === false && data.message) throw data.message;

            this.editedProjectedHours = { projectedHours: '', actualHours: '' };
            this.showModalSpinner = false;
            return data.result;
        }).catch((error) => {
            Utilities.Notification.handleError(error);
            this.showModalSpinner = false;
            return error;
        });
    }

    submitForecast(resourceId, date) {
        this.showSpinner = true;
        return Utilities.Apex.invoke(
            'RPRFResourcePlanningController',
            'submitForecast',
            { resourceId, date }
        ).then((data) => {
            if(data.success === false && data.message) throw data.message;

            this.weekConfiguration.hasSubmitedForecast = true;
            this.showSpinner = false;

            Utilities.Notification.show('Information', 'The forecast was successfully submitted', Utilities.Notification.TYPE.SUCCESS);
            return data.result;
        }).catch((error) => {
            this.showSpinner = false;
            Utilities.Notification.handleError(error);
            return error;
        });
    }

    prepareAssignments(assignments) {
        let dayTotals = {}, 
            result = assignments.map(assignment => {
                return this.buildDailyAssignmentRow(assignment, dayTotals);
            });

        result.push(this.buildDailyAssignmentTotalRow(dayTotals));
        return result;
    }

    buildDailyAssignmentRow(assignment, dayTotals) {
        const dataByDays = this.allDatesOfCurrentWeek.map((date, index) => {
            const dataByDay = { Daily_Date__c: date, Contact__c: assignment.Resource__c };
            const isWeekend = index === 0 || index === (this.allDatesOfCurrentWeek.length - 1);
            const dailyAssignment = assignment.Daily_Assignments__r?.find(item => item.Daily_Date__c === date);
            const isPastDate = Utilities.getLocalDateFromISOString(date) < new Date();

            let isPTO = this.hasDayOff('pto', dataByDay);
            let isHolidays = this.hasDayOff('holidays', dataByDay);
            let isOutRangeDate = this.hasOutRangeDate(assignment, dataByDay);
            let helpText = this.getAssignmentsByDayHelpText({ isPTO, isHolidays, dailyAssignment: dataByDay });
            let isEditableField = this.canEditDailyAssignment({ isPTO, isHolidays, isOutRangeDate, isWeekend });

            if (dailyAssignment) {
                isPTO = this.hasDayOff('pto', dailyAssignment);
                isHolidays = this.hasDayOff('holidays', dailyAssignment);
                isOutRangeDate = this.hasOutRangeDate(assignment, dailyAssignment);
                isEditableField = this.canEditDailyAssignment({ isPTO, isHolidays, isOutRangeDate, isWeekend, record: dailyAssignment });
                helpText = this.getAssignmentsByDayHelpText({ isPTO, isHolidays, dailyAssignment });
   
                const projectedHours = dailyAssignment.Projected_Hours__c ? Number(dailyAssignment.Projected_Hours__c) : 0;
                const actualHours = dailyAssignment.Actual_Hours__c ? Number(dailyAssignment.Actual_Hours__c) : 0;

                if(!dayTotals[date]) dayTotals[date] = {projectedHours: 0, actualHours: 0};
                dayTotals[date].projectedHours += projectedHours;
                dayTotals[date].actualHours += actualHours;
                
                return {
                    dailyDate: dailyAssignment.Daily_Date__c,
                    projectedHours: dailyAssignment.Projected_Hours__c ?? '',
                    actualHours: dailyAssignment.Actual_Hours__c ?? '',
                    hours: this.buildDayValue({hasHours: true, projectedHours, actualHours, isPastDate}),
                    className: this.buildDayDesign({isWeekend, isHoliday: isHolidays, isPTO, isOutRange: isOutRangeDate, isLocked: dailyAssignment.Locked__c, isEditable: isEditableField, date, index, projectedHours: dailyAssignment.Projected_Hours__c, actualHours: dailyAssignment.Actual_Hours__c, isPastDate}),
                    isLocked: dailyAssignment.Locked__c,
                    helpText,
                    index: Math.random(),
                    onClick: function() {
                        if(!isEditableField) return;

                        this.handleEditProjectedHoursModalOpen({
                            id: dailyAssignment.Id,
                            dailyDate: dailyAssignment.Daily_Date__c,
                            actualHours: dailyAssignment.Actual_Hours__c ?? '',
                            projectedHours: dailyAssignment.Projected_Hours__c ?? '',
                            canSave: !isPastDate //&& !dailyAssignment.Locked__c
                        });
                    }
                };
            }

            return {
                dailyDate: date,
                projectedHours: '',
                hours: '',
                helpText: '',
                className: this.buildDayDesign({isWeekend, isHoliday: isHolidays, isPTO, isOutRange: isOutRangeDate, isEditable: isEditableField, date, index, isPastDate}),
                isLocked: false,
                index: Math.random(),
                onClick: function() {
                    if(isWeekend || isOutRangeDate || isHolidays || isPTO) return;

                    this.handleEditProjectedHoursModalOpen({
                        id: null,
                        dailyDate: date,
                        actualHours: '',
                        projectedHours: '',
                        canSave: !isPastDate
                    });
                },
                ...((isHolidays || isPTO) ? { helpText } : {}),
            };
        });

        const projectedHoursTotal = dataByDays.reduce((accumulator, value) => accumulator + (Number(value.projectedHours) || 0), 0);
        const actualHoursTotal = dataByDays.reduce((accumulator, value) => accumulator + (Number(value.actualHours) || 0), 0);

        let hasPastDate = false;
        this.allDatesOfCurrentWeek.forEach(function (date) {
            hasPastDate |= Utilities.getLocalDateFromISOString(date) < new Date();
        });

        return {
            id: `${assignment.Resource__c}-${assignment.Id}`,
            assignmentId: assignment.Id,
            projectId: assignment.Projects__c,
            assignmentIdLink: `/${assignment.Id}`,
            projectIdLink: `/${assignment.Projects__c}`,
            assignmentName: assignment.Name,
            projectName: assignment.Projects__r.Name,
            assignmentStartDate: assignment.Start_Date__c,
            assignmentEndDate: assignment.End_Date__c,
            assignmentStartDateLocale: this.convertDateToLocaleString(assignment.Start_Date__c),
            assignmentEndDateLocale: this.convertDateToLocaleString(assignment.End_Date__c),
            assignmentEstHours: assignment.Number_Of_Hours__c,
            remainingAssignmentHours: assignment.Assignment_Hours_Remaining__c,
            assignmentMaxDailyHours: assignment.Daily_Max__c,
            messageOnAssignment: assignment.message,
            dataByDays,
            totalHours: this.buildDayValue({hasHours: true, projectedHours: projectedHoursTotal, actualHours: actualHoursTotal, isPastDate: hasPastDate}),
            totalHoursClassName: this.buildDayDesign({projectedHoursTotal, actualHoursTotal, isAssignmentTotals: true, hasHours: true, isPastDate: hasPastDate})
        };
    }

    buildDailyAssignmentTotalRow(dayTotals) {
        const projectedHoursAllTotal = Object.keys(dayTotals).reduce(function (previous, key) {
            return previous + dayTotals[key].projectedHours || 0;
        }, 0);

        const actualHoursAllTotal = Object.keys(dayTotals).reduce(function (previous, key) {
            return previous + dayTotals[key].actualHours || 0;
        }, 0);

        let hasPastDate = false;
        Object.keys(dayTotals).forEach(function (date) {
            hasPastDate |= Utilities.getLocalDateFromISOString(date) < new Date();
        });

        return {
            id: 'totals',
            dataByDays: this.allDatesOfCurrentWeek.map((date, index) => {
                const projectedHoursTotal = dayTotals[date]?.projectedHours || 0;
                const actualHoursTotal = dayTotals[date]?.actualHours || 0;
                const isHoliday = this.hasDayOff('holidays', { Daily_Date__c: date });
                const isWeekend = index === 0 || index === (this.allDatesOfCurrentWeek.length - 1);
                const hasHours = (!isWeekend && !isHoliday) || projectedHoursTotal > 0 || actualHoursTotal > 0;
                const isPastDate = Utilities.getLocalDateFromISOString(date) < new Date();

                return {
                    dailyDate: date,
                    projectedHours: projectedHoursTotal,
                    actualHours: actualHoursTotal,
                    hours: this.buildDayValue({hasHours, projectedHours: projectedHoursTotal, actualHours: actualHoursTotal, isPastDate}),
                    className: this.buildDayDesign({isWeekend, isHoliday, hasHours, projectedHoursTotal, actualHoursTotal, date, index, isDayTotals: true, isPastDate}),
                    helpText: '',
                    index: Math.random(),
                    onClick: function() {}
                }
            }),
            totalHours: this.buildDayValue({hasHours: true, projectedHours: projectedHoursAllTotal, actualHours: actualHoursAllTotal, isPastDate: hasPastDate}),
            totalHoursClassName: this.buildDayDesign({projectedHoursTotal: projectedHoursAllTotal, actualHoursTotal: actualHoursAllTotal, isAssignmentTotals: true, isDayTotals: true, hasHours: true, isPastDate: hasPastDate})
        };
    }

    buildDayValue(params) {
        if(!params.hasHours) return '';

        const projectedHours = params.projectedHours || 0;
        const actualHours = params.actualHours || 0;

        if(params.isPastDate) {
            return projectedHours + '/' + actualHours;
        }
        
        return projectedHours;
    }

    buildDayDesign(params) {
        let result = 'slds-is-relative';

        if(params.isDayTotals && params.isAssignmentTotals) {
            result += ' total-hours-by-days';
            if(params.hasHours) {
                if(params.projectedHoursTotal > 0 || params.actualHoursTotal > 0){
                    if(params.projectedHoursTotal <= params.actualHoursTotal) result += ' rp-day-total-green';
                    else if(params.isPastDate || params.actualHoursTotal > 0) result += ' rp-day-total-red';
                }
            }
        }else if(params.isDayTotals) {
            result += ' assignment-hours-by-days';
            if(params.hasHours) {
                if(params.projectedHoursTotal > 0 || params.actualHoursTotal > 0){
                    if(params.projectedHoursTotal <= params.actualHoursTotal) result += ' rp-day-total-green';
                    else if(params.isPastDate || params.actualHoursTotal > 0) result += ' rp-day-total-red';
                }
            }
        }else if(params.isAssignmentTotals) {
            result += ' total-assignment-hours-by-days';
            if(params.hasHours) {
                if(params.projectedHoursTotal > 0 || params.actualHoursTotal > 0){
                    if(params.projectedHoursTotal <= params.actualHoursTotal) result += ' rp-day-total-green';
                    else if(params.isPastDate || params.actualHoursTotal > 0) result += ' rp-day-total-red';
                }
            }
        }else{
            result += ' assignment-hours-by-days';

            const projectedHours = Number(params.projectedHours ?? '0');
            const actualHours = Number(params.actualHours ?? '0');
            const hasHours = !params.isPTO && !params.isOutRange && !params.isHoliday && (projectedHours > 0 || actualHours > 0);

            if(hasHours){
                if(projectedHours <= actualHours) result += ' rp-day-status-green';
                else if(params.isPastDate || actualHours > 0) result += ' rp-day-status-red';
            }
        }

        if(params.isWeekend) result += ' rp-weekend-day';
        if(params.isHoliday) result += ' rp-holidays';
        if(params.isPTO) result += ' rp-pto';
        if(params.isOutRange) result += ' rp-out-range-date';
        if(params.isLocked) result += ' rp-day-locked';
        if(params.isEditable) result += ' field-edit';

        return result;
    }

    hasDayOff(dayOffType, dailyAssignment) {
        let dayOff = this.daysOff[dailyAssignment.Daily_Date__c];
        if(dayOff && dayOffType == 'holidays') {
            dailyAssignment.descriptionOfWork = dayOff.Description_of_Work__c;
            return true;
        }

        dayOff = this.daysOff[dailyAssignment.Daily_Date__c + dailyAssignment.Contact__c];
        if(dayOff && dayOffType == 'pto') {
            dailyAssignment.descriptionOfWork = dayOff.Description_of_Work__c;
            return true;
        }

        return false;
    }

    hasOutRangeDate(assignment, dailyAssignment) {
        return Utilities.getLocalDateFromISOString(assignment.Start_Date__c) > Utilities.getLocalDateFromISOString(dailyAssignment.Daily_Date__c) || 
                Utilities.getLocalDateFromISOString(assignment.End_Date__c) < Utilities.getLocalDateFromISOString(dailyAssignment.Daily_Date__c);
    }

    getAssignmentsByDayHelpText(data) {
        const { isPTO, isHolidays, dailyAssignment } = data;
        let helpText = '';

        if (isHolidays) {
            helpText = `Holidays \n${dailyAssignment.descriptionOfWork}`;
        } else if (isPTO) {
            helpText = `PTO \n${dailyAssignment.descriptionOfWork}`;
        } else if (dailyAssignment.Locked__c) {
            helpText = dailyAssignment.Lock_Reason__c ? dailyAssignment.Lock_Reason__c : 'Locked due to manual changes';
        }

        return helpText;
    }

    canEditDailyAssignment(data) {
        const { isPTO, isHolidays, isOutRangeDate, isWeekend, record } = data;

        /*
        let locked = record?.Locked__c && 
                        record?.Locked_By__c != this.configuration?.currentUser?.Id && 
                        record?.Projects__r?.Project_Lead__r?.Resource_User_Record__c != this.configuration?.currentUser?.Id;

        return !locked && !isPTO && !isHolidays && !isWeekend && !isOutRangeDate;
        */
        return !isPTO && !isHolidays && !isWeekend && !isOutRangeDate;
    }

    handleRefresh() {
        this.refresh();
    }

    handleResourceChanged(event) {
        this.selectedResourceId = event.detail.id;
        this.refresh();
    }

    handleProjectChanged(event) {
        this.selectedProjectId = event.detail.id;
        this.refresh();
    }

    handleSelectedDateChanged(event) {
        this.selectedDate = event.detail.value;
        this.updateAllDatesOfCurrentWeek(this.selectedDate);
        this.getResourcePlanningData();
    }

    handlePreviousWeek() {
        if (this.allDatesOfCurrentWeek.length === 0) return;

        const currentWeekStart = Utilities.getLocalDateFromISOString(this.allDatesOfCurrentWeek[0]);
        this.selectedDate = Utilities.getLocalDateISOString(new Date(currentWeekStart.setDate(currentWeekStart.getDate() - 7)));
        this.updateAllDatesOfCurrentWeek(this.selectedDate);
        if (this.isCurrentWeek) this.selectedDate = this.CURRENT_DATE;
        this.getResourcePlanningData();
    }

    handleNextWeek() {
        if (this.allDatesOfCurrentWeek.length === 0) return;

        const currentWeekEnd = Utilities.getLocalDateFromISOString(this.allDatesOfCurrentWeek[this.allDatesOfCurrentWeek.length - 1]);
        this.selectedDate = Utilities.getLocalDateISOString(new Date(currentWeekEnd.setDate(currentWeekEnd.getDate() + 1)));
        this.updateAllDatesOfCurrentWeek(this.selectedDate);
        if (this.isCurrentWeek) this.selectedDate = this.CURRENT_DATE;
        this.getResourcePlanningData();
    }
    
    handleSubmitForecast() {
        const now = Utilities.getLocalDateFromISOString(this.CURRENT_DATE);
        const startOfNextWeek = new Date(new Date(now).setDate(now.getDate() - now.getDay() + 7));
        this.submitForecast(this.selectedResourceId, Utilities.getLocalDateISOString(startOfNextWeek)).then(() => {});
    }

    handleEditProjectedHoursModalOpen(editedProjectedHoursData) {
        this.editedProjectedHours = { ...editedProjectedHoursData };
        this.showEditProjectedHoursModal = true;
        this.renderTrigger++;
    }

    handleEditProjectedHoursModalClose() {
        this.showEditProjectedHoursModal = false;
        this.showModalSpinner = false;
    }

    handleViewRecord() {
        this[NavigationMixin.GenerateUrl]({
            type: 'standard__recordPage',
            attributes: {
                recordId: this.editedProjectedHours.id,
                actionName: 'view',
            },
        }).then((url) => {
            this.handleEditProjectedHoursModalClose();
            window.open(url, '_blank');
        });
    }

    handleEditProjectedHoursChanged(event) {
        this.editedProjectedHours.projectedHours = event.detail.value;
        this.renderTrigger++;
    }

    handleSaveProjectedHours() {
        const { id, projectedHours } = this.editedProjectedHours;

        this.saveDailyAssignment(id, projectedHours).then(() => {
            this.handleEditProjectedHoursModalClose();
            this.refresh();
        });
    }

    handleAssignmentClick(event) {
        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                objectApiName: "SFDC_Assignment__c",
                recordId: event.target.dataset.idx,
                actionName: "view"
            }
        });
    }

    handleProjectClick(event) {
        this[NavigationMixin.Navigate]({
            type: "standard__recordPage",
            attributes: {
                objectApiName: "SFDC_Projects__c",
                recordId: event.target.dataset.idx,
                actionName: "view"
            }
        });
    }
}