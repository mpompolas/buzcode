function [ints, idx, MinTimeWindowParms] = ClusterStates_DetermineStates(...
    SleepScoreMetrics,MinTimeWindowParms,histsandthreshs)
% can input histsandthreshs from externally if needed... ie via manual
% selection in stateeditor

%% Basic parameters
% Min Win Parameters (s)
if exist('MinTimeWindowParms','var') && ~isempty(MinTimeWindowParms)
     v2struct(MinTimeWindowParms)
else%defaults as follows:
    minSWSsecs = 6;
    minWnexttoREMsecs = 6;
    minWinREMsecs = 6;       
    minREMinWsecs = 6;
    minREMsecs = 6;
    minWAKEsecs = 6;
    MinTimeWindowParms = v2struct(minSWSsecs,minWnexttoREMsecs,minWinREMsecs,...
        minREMinWsecs,minREMsecs,minWAKEsecs);
end

% handling variables for determining thresholds/cutoffs
if exist('histsandthreshs','var')
    hat2 = histsandthreshs;%bc will overwrite below
    v2struct(SleepScoreMetrics)
    histsandthreshs = hat2;
else
    v2struct(SleepScoreMetrics)
end
v2struct(histsandthreshs)%Expand and get values out of these fields

%% Re-Do this code (should be same as in ClusterStates_GetParams.m) to see if theta is bimodal

%This switch turns on a "schmidt trigger", or sticky trigger,
%which means that threshold crossings have to reach the
%midpoint between the dip and the opposite peak, this
%reduces noise. Passed through via histsandthreshs from checkboxes in
%TheStateEditor or 'stickytrigger',true in SleepScoreMaster via GetMetrics
if ~exist('stickySW','var'); stickySW = false; end
if ~exist('stickyTH','var'); stickyTH = false; end
if ~exist('stickyEMG','var'); stickyEMG = false; end


[~,~,~,~,NREMtimes] = bz_BimodalThresh(broadbandSlowWave(:),'startbins',15,...
    'setthresh',swthresh,'diptest',false,'Schmidt',stickySW,'0Inf',true);

[~,~,~,~,hightheta] = bz_BimodalThresh(thratio(:),'startbins',15,...
    'setthresh',THthresh,'diptest',false,'Schmidt',stickyTH,'0Inf',true);

[~,~,~,~,highEMG] = bz_BimodalThresh(EMG(:),'startbins',15,...
    'setthresh',EMGthresh,'diptest',false,'Schmidt',stickyEMG,'0Inf',true);

REMtimes = (~NREMtimes & ~highEMG & hightheta);


%OLD
%NREMtimes = (broadbandSlowWave >swthresh);
%MOVtimes = (broadbandSlowWave(:)<swthresh & EMG(:)>EMGthresh); Not actually used
% if THthresh ~= 0
%     REMtimes = (broadbandSlowWave(:)<swthresh & EMG(:)<EMGthresh & thratio(:)>THthresh);
% else % THthresh = 0;
%     REMtimes =(broadbandSlowWave(:)<swthresh & EMG(:)<EMGthresh);
% end    

%%
%OLD:
%Index Vector: SWS=2, REM=3, MOV=6, NonMOV=1.   
%(Separate MOV for REM, then join later)
%IDX = SWStimes+2*REMtimes+5*MOVtimes+1;

%NEW: No separation of MOV and NonMOV WAKE
%Index Vector: NREM=2, REM=3, WAKE=1. 
IDX = NREMtimes+2*REMtimes+1;

%Start/end offset due to FFT


%% Minimum Interuptions
INT = IDXtoINT(IDX,3);


%Make the following repeated chunks of code into a single function.

%SWS  (to NonMOV)
Sints = INT{2};
Slengths = Sints(:,2)-Sints(:,1);
shortSints = {Sints(find(Slengths<=minSWSsecs),:)};
shortSidx = bz_INTtoIDX(shortSints,'length',length(IDX));
%Change Short SWS to Wake
IDX(shortSidx==1) = 1;   
INT = IDXtoINT(IDX,3);

%NonMOV next to REM   (to REM)
Wints = INT{1};
trans = (diff(IDX)); %All State Transitions
WRtrans = find((trans)==-2)+1;  %Just transitions between WAKE, REM
%Convert to interval indices
[~,WRtransON] = intersect(Wints(:,1),WRtrans);
WRtrans = find((trans)==2);
[~,WRtransOFF] = intersect(Wints(:,2),WRtrans);
WRtrans = union(WRtransON,WRtransOFF); %On or offset are RW
%Find WAKE intervals that border REM and are less than min
Wlengths = Wints(:,2)-Wints(:,1);
shortWRints = find(Wlengths(WRtrans)<=minWnexttoREMsecs);
shortWRints = WRtrans(shortWRints);
shortWRints = {Wints(shortWRints,:)};
shortWRidx = bz_INTtoIDX(shortWRints,'length',length(IDX));
%Convert wake to rem
IDX(shortWRidx==1) = 3;
INT = IDXtoINT(IDX,3);


%NonMOV in REM   (to REM)
Wints = INT{1};
trans = (diff(IDX)); %All State Transitions
WRtrans = find((trans)==-2)+1;  %Just transitions between WAKE, REM
%Convert to interval indices
[~,WRtransON] = intersect(Wints(:,1),WRtrans);
WRtrans = find((trans)==2);
[~,WRtransOFF] = intersect(Wints(:,2),WRtrans);
WRtrans = intersect(WRtransON,WRtransOFF); %Both onset and offset are RW
%Find WAKE intervals that border REM and are less than min
Wlengths = Wints(:,2)-Wints(:,1);
shortWRints = find(Wlengths(WRtrans)<=minWinREMsecs);
shortWRints = WRtrans(shortWRints);
shortWRints = {Wints(shortWRints,:)};
shortWRidx = bz_INTtoIDX(shortWRints,'length',length(IDX));
%Convert wake to rem
IDX(shortWRidx==1) = 3;
IDX(IDX==6) = 1; %Convert NonMOV to WAKE
INT = IDXtoINT(IDX,3);


%REM in WAKE   (to WAKE)
Rints = INT{3};
trans = (diff(IDX)); %All State Transitions
WRtrans = find((trans)==2)+1;  %Just transitions between WAKE, REM
%Convert to interval indices
[~,WRtransON] = intersect(Rints(:,1),WRtrans);
WRtrans = find((trans)==-2);
[~,WRtransOFF] = intersect(Rints(:,2),WRtrans);
WRtrans = intersect(WRtransON,WRtransOFF); %Both onset and offset are RW
%Find WAKE intervals that border REM and are less than min
Rlengths = Rints(:,2)-Rints(:,1);
shortWRints = find(Rlengths(WRtrans)<=minREMinWsecs);
shortWRints = WRtrans(shortWRints);
shortWRints = {Rints(shortWRints,:)};
shortWRidx = bz_INTtoIDX(shortWRints,'length',length(IDX));
%Convert REM to WAKE
IDX(shortWRidx==1) = 1;
INT = IDXtoINT(IDX,3);

%REM (only applies to REM in the middle of SWS)    (to WAKE)
Rints = INT{3};
Rlengths = Rints(:,2)-Rints(:,1);
shortRints = {Rints(find(Rlengths<=minREMsecs),:)};
shortRidx = bz_INTtoIDX(shortRints,'length',length(IDX));

IDX(shortRidx==1) = 1;
INT = IDXtoINT(IDX,3);


%WAKE   (to SWS)     essentiall a minimum MA time
Wints = INT{1};
Wlengths = Wints(:,2)-Wints(:,1);
shortWints = {Wints(find(Wlengths<=minWAKEsecs),:)};
shortWidx = bz_INTtoIDX(shortWints,'length',length(IDX));
IDX(shortWidx==1) = 2;

INT = IDXtoINT(IDX,3);

%SWS  (to NonMOV)
Sints = INT{2};
Slengths = Sints(:,2)-Sints(:,1);
shortSints = {Sints(find(Slengths<=minSWSsecs),:)};
shortSidx = bz_INTtoIDX(shortSints,'length',length(IDX));
%Change Short SWS to Wake
IDX(shortSidx==1) = 1;

%Here: use SleepScoreMetrics.t_clus to align IDX to timestamps that are
%then passed through to get final start/stops (set any timestamps that
%weren't scored (i.e. weren't extracted in the SleepScoreLFP to 0)

INT = IDXtoINT(IDX,3);




%% Pad time to match recording time
offset = SleepScoreMetrics.t_clus(1)-1; %t_FFT(1)-1;
INT = cellfun(@(x) x+offset,INT,'UniformOutput',false);

%% Structure Output

%Defaults - quick bug fix if some state doesn't exist
ints.WAKEstate = [];ints.NREMstate = [];ints.REMstate = [];

ints.WAKEstate = INT{1};
ints.NREMstate = INT{2};
ints.REMstate = INT{3};

%Because TheStateEditor
idx = bz_INTtoIDX(ints,'statenames',{'WAKE','','NREM','','REM'},'length',t_clus(end));


end

