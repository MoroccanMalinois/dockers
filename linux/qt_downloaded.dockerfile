FROM ubuntu
MAINTAINER MoroccanMalinois <MoroccanMalinois@protonmail.com>

RUN apt-get update && apt-get install -y xvfb libfontconfig1 libdbus-1-3 vim libglib2.0-0 make wget

#INSTALL Qt
ENV QT_BRANCH 5.7
ENV QT_VERSION 5.7.1
RUN cd /usr \
    && wget -q http://download.qt.io/official_releases/qt/${QT_BRANCH}/${QT_VERSION}/qt-opensource-linux-x64-${QT_VERSION}.run \
    && chmod +x qt-opensource-linux-x64-${QT_VERSION}.run


RUN echo "\
function Controller() {\
    installer.autoRejectMessageBoxes();\
    installer.installationFinished.connect(function() {\
        gui.clickButton(buttons.NextButton);\
    })\
}\
Controller.prototype.WelcomePageCallback = function() {\
    gui.clickButton(buttons.NextButton);\
}\
Controller.prototype.CredentialsPageCallback = function() {\
    gui.clickButton(buttons.NextButton);\
}\
Controller.prototype.IntroductionPageCallback = function() {\
    gui.clickButton(buttons.NextButton);\
}\
Controller.prototype.TargetDirectoryPageCallback = function() {\
    gui.currentPageWidget().TargetDirectoryLineEdit.setText(\"/usr/qt\");\
    gui.clickButton(buttons.NextButton);\
}\
Controller.prototype.ComponentSelectionPageCallback = function() {\
    var widget = gui.currentPageWidget();\
    widget.deselectAll();\
    widget.selectComponent(\"qt.57.gcc_64\");\
    gui.clickButton(buttons.NextButton);\
}\
Controller.prototype.LicenseAgreementPageCallback = function() {\
    gui.currentPageWidget().AcceptLicenseRadioButton.setChecked(true);\
    gui.clickButton(buttons.NextButton);\
}\
Controller.prototype.StartMenuDirectoryPageCallback = function() {\
    gui.clickButton(buttons.NextButton);\
}\
Controller.prototype.ReadyForInstallationPageCallback = function() {\
    gui.clickButton(buttons.NextButton);\
}\
Controller.prototype.FinishedPageCallback = function() {\
var checkBoxForm = gui.currentPageWidget().LaunchQtCreatorCheckBoxForm;\
if (checkBoxForm && checkBoxForm.launchQtCreatorCheckBox) {\
    checkBoxForm.launchQtCreatorCheckBox.checked = false;\
}\
    gui.clickButton(buttons.FinishButton);\
}\
" > /usr/qt_installer.qs

RUN cd /usr \
    && xvfb-run ./qt-opensource-linux-x64-${QT_VERSION}.run  --script qt_installer.qs 
#| egrep -v '\[[0-9]+\] Warning: (Unsupported screen format)|((QPainter|QWidget))'

