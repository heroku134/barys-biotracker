package com.yc.nadalsdkdemo;

import android.Manifest;
import android.app.ProgressDialog;
import android.content.Intent;
import android.content.res.ColorStateList;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.os.Message;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.TextView;

import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;
import androidx.recyclerview.widget.GridLayoutManager;

import com.google.gson.Gson;
import com.jieli.jl_bt_ota.util.BluetoothUtil;
import com.jieli.jl_bt_ota.util.CHexConver;
import com.tbruyelle.rxpermissions.RxPermissions;
import com.yc.nadalsdk.annotation.SwitchState;
import com.yc.nadalsdk.bean.ActivateWarrantyTimeConfig;
import com.yc.nadalsdk.bean.Alarm;
import com.yc.nadalsdk.bean.AlarmCountParamBean;
import com.yc.nadalsdk.bean.AppPermissionSet;
import com.yc.nadalsdk.bean.CameraStatusConfig;
import com.yc.nadalsdk.bean.DeviceActiveInfo;
import com.yc.nadalsdk.bean.DeviceDebugState;
import com.yc.nadalsdk.bean.DeviceInfoRequest;
import com.yc.nadalsdk.bean.DevicePairedState;
import com.yc.nadalsdk.bean.DevicePasswordConfig;
import com.yc.nadalsdk.bean.DeviceResetNotify;
import com.yc.nadalsdk.bean.DownloadConfig;
import com.yc.nadalsdk.bean.ElectronicCardInfo;
import com.yc.nadalsdk.bean.HealthLabFunStatusInfo;
import com.yc.nadalsdk.bean.HonorAccountConfig;
import com.yc.nadalsdk.bean.JLOtaSecondModeNotify;
import com.yc.nadalsdk.bean.MusicAppPlayInfo;
import com.yc.nadalsdk.bean.MusicAppStatus;
import com.yc.nadalsdk.bean.NaviSearchResultInfo;
import com.yc.nadalsdk.bean.Notify;
import com.yc.nadalsdk.bean.PackageHeader;
import com.yc.nadalsdk.bean.RegionLockConfig;
import com.yc.nadalsdk.bean.Response;
import com.yc.nadalsdk.bean.ScreenInfoConfig;
import com.yc.nadalsdk.bean.SoundVibrationConfig;
import com.yc.nadalsdk.bean.SupportCommandRequest;
import com.yc.nadalsdk.bean.TimeClock;
import com.yc.nadalsdk.bean.TimeDisplay;
import com.yc.nadalsdk.bean.TwoWaySettingConfig;
import com.yc.nadalsdk.bean.UpgradeConfig;
import com.yc.nadalsdk.bean.VersionConfig;
import com.yc.nadalsdk.bean.WorldClockInfo;
import com.yc.nadalsdk.ble.open.AIGlassesMode;
import com.yc.nadalsdk.ble.open.AiApiUtils;
import com.yc.nadalsdk.ble.open.DeviceModeJX;
import com.yc.nadalsdk.ble.open.TwoWayDisplayJX;
import com.yc.nadalsdk.ble.open.UteBleClient;
import com.yc.nadalsdk.ble.open.UteBleConnection;
import com.yc.nadalsdk.ble.open.UteBleDevice;
import com.yc.nadalsdk.constants.AlarmSoundMode;
import com.yc.nadalsdk.constants.LanguageType;
import com.yc.nadalsdk.constants.NotifyType;
import com.yc.nadalsdk.constants.ServiceIds;
import com.yc.nadalsdk.constants.WeekCycle;
import com.yc.nadalsdk.listener.BleConnectStateListener;
import com.yc.nadalsdk.listener.DeviceNotifyListener;
import com.yc.nadalsdk.listener.FileService;
import com.yc.nadalsdk.listener.OlmNaviSyncListener;
import com.yc.nadalsdk.log.LogShareUtils;
import com.yc.nadalsdk.log.LogUtils;
import com.yc.nadalsdk.utils.open.ErrorCode;
import com.yc.nadalsdk.utils.open.GBUtils;
import com.yc.nadalsdkdemo.actota.ActsOtaActivity;
import com.yc.nadalsdkdemo.basebinding.BaseActivity;
import com.yc.nadalsdkdemo.clip.ClipCustomActivity;
import com.yc.nadalsdkdemo.databinding.ActivityBleDeviceBinding;
import com.yc.nadalsdkdemo.jl.JLOtaActivity;
import com.yc.nadalsdkdemo.jl.JLOtaUtil;
import com.yc.nadalsdkdemo.jl.SPDao;
import com.yc.nadalsdkdemo.smartglasses.SmartGlassesActivity;
import com.yc.nadalsdkdemo.test.PushTestActivity;
import com.yc.nadalsdkdemo.utils.FakeWatchManager;
import com.yc.nadalsdkdemo.utils.StringUtil;
import com.yc.nadalsdkdemo.utils.ToastUtil;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.concurrent.Future;
import java.util.concurrent.TimeUnit;

import io.reactivex.Flowable;
import io.reactivex.android.schedulers.AndroidSchedulers;
import rx.functions.Action1;

public class BleDeviceActivity extends BaseActivity<ActivityBleDeviceBinding> implements CommonButtonAdapter.OnButtonClickListener {
    public static final String DEVICE_ADDRESS = "device_address";
    public static final String DEVICE_NAME = "device_name";
    private ProgressDialog mProgressDialog;
    private UteBleClient mUteBleClient;
    private UteBleConnection mUteBleConnection;
    private String deviceAddress;
    private String deviceName;
    private List<Integer> mFunctionBit = new ArrayList<>();
    private int mAlarmCount = 5;
    private void setListener() {
        mUteBleConnection.setDeviceNotifyListener(mDeviceNotifyListener);
    }
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
//        setContentView(R.layout.activity_ble_device);
        mProgressDialog = new ProgressDialog(this);
        deviceAddress = getIntent().getStringExtra(DEVICE_ADDRESS);
        deviceName = getIntent().getStringExtra(DEVICE_NAME);
        updateTextView(binding.tvDetails, deviceName + "(" + deviceAddress + ")");
        mUteBleClient = MyApplication.getBleClient();

        mUteBleConnection = mUteBleClient.getUteBleConnection();
        LogUtils.i("BleDeviceActivity   mUteBleClient =" + mUteBleClient);
        if (MyApplication.isFakeDeviceMode() || "00:11:22:33:44:55".equals(deviceAddress)) {
            MyApplication.setFakeDeviceMode(true);
            mUteBleConnection.setConnectStateListener(mBleConnectStateListener);
            connectDevice(deviceAddress);
        } else if (mUteBleClient.isBluetoothEnable()) {
            //必须在调用连接方法前设置监听。
            mUteBleConnection.setConnectStateListener(mBleConnectStateListener);
            connectDevice(deviceAddress);
        } else {
            ToastUtil.showToast("Please turn on your phone's bluetooth");
        }
        List<Integer> buttonResIdList = Arrays.asList(
                R.string.heartRate,
                R.string.fitness,
                R.string.workout,
                R.string.bt_temperature_module,
                R.string.blood_sugar,
                R.string.getBatteryInfo,
                R.string.getDeviceInfo,
                R.string.setFindWearCmd,
                R.string.setFindMyPhone,
                R.string.setDisconnectRemind,
                R.string.setSoundVibrationConfig,
                R.string.querySoundVibrationConfig,
                R.string.getAlarmList,
                R.string.setAlarmList,
                R.string.queryDeviceSupAlarmCountParam,
                R.string.bt_app_remind,
                R.string.notifyIncomingCall,
                R.string.notifyHangup,
                R.string.notifyAnswerCall,
                R.string.setTimeClock,
                R.string.getTimeClock,
                R.string.setLanguage,
                R.string.resetFactory,
                R.string.bt_acts_ota,
                R.string.bt_jl_ota,
                R.string.bt_share_log,
                R.string.contacts_and_sos,
                R.string.drinkWaterRemind
        );
        binding.rvButtonList.setLayoutManager(new GridLayoutManager(this, 3));
        CommonButtonAdapter adapter = new CommonButtonAdapter(this, buttonResIdList, this);
        binding.rvButtonList.setAdapter(adapter);

        binding.tvSdkToolsHeader.setOnClickListener(v -> {
            if (binding.rvButtonList.getVisibility() == View.VISIBLE) {
                binding.rvButtonList.setVisibility(View.GONE);
                binding.tvSdkToolsHeader.setText("🛠️ Инструменты разработчика UTE SDK (развернуть)");
            } else {
                binding.rvButtonList.setVisibility(View.VISIBLE);
                binding.tvSdkToolsHeader.setText("🛠️ Инструменты разработчика UTE SDK (свернуть)");
            }
        });

        // Setup Sensor Telemetry Dashboard Card Click Listeners
        binding.cardHeart.setOnClickListener(v -> {
            com.yc.nadalsdkdemo.utils.AudioHapticHelper.mechanicalClick(this, v);
            startActivity(new Intent(this, HeartRateActivity.class));
        });
        binding.cardSpo2.setOnClickListener(v -> {
            com.yc.nadalsdkdemo.utils.AudioHapticHelper.mechanicalClick(this, v);
            startActivity(new Intent(this, FitnessActivity.class));
        });
        binding.cardTemp.setOnClickListener(v -> {
            com.yc.nadalsdkdemo.utils.AudioHapticHelper.mechanicalClick(this, v);
            startActivity(new Intent(this, TemperatureModuleActivity.class));
        });
        binding.cardSteps.setOnClickListener(v -> {
            com.yc.nadalsdkdemo.utils.AudioHapticHelper.mechanicalClick(this, v);
            startActivity(new Intent(this, FitnessActivity.class));
        });
        binding.cardSleep.setOnClickListener(v -> {
            com.yc.nadalsdkdemo.utils.AudioHapticHelper.mechanicalClick(this, v);
            startActivity(new Intent(this, FitnessActivity.class));
        });
        binding.ivAvatar.setOnClickListener(v -> {
            com.yc.nadalsdkdemo.utils.AudioHapticHelper.mechanicalClick(this, v);
            startActivity(new Intent(this, ProfileActivity.class));
        });
        binding.cardDevice.setOnClickListener(v -> {
            com.yc.nadalsdkdemo.utils.AudioHapticHelper.mechanicalClick(this, v);
            startActivity(new Intent(this, DeviceActivity.class));
        });
        binding.cardBioAvatar.setOnClickListener(v -> {
            com.yc.nadalsdkdemo.utils.AudioHapticHelper.heavyEngage(this);
            startActivity(new Intent(this, com.yc.nadalsdkdemo.avatar.BioAvatarActivity.class));
        });
        binding.btnFloatingAvatar.setOnClickListener(v -> {
            com.yc.nadalsdkdemo.utils.AudioHapticHelper.heavyEngage(this);
            startActivity(new Intent(this, com.yc.nadalsdkdemo.avatar.BioAvatarActivity.class));
        });

        binding.bottomNavigation.setOnItemSelectedListener(item -> {
            int itemId = item.getItemId();
            com.yc.nadalsdkdemo.utils.AudioHapticHelper.mechanicalClick(this);
            if (itemId == R.id.nav_dashboard) {
                return true;
            } else if (itemId == R.id.nav_sport) {
                startActivity(new Intent(this, WorkOutActivity.class));
                return true;
            } else if (itemId == R.id.nav_avatar) {
                startActivity(new Intent(this, com.yc.nadalsdkdemo.avatar.BioAvatarActivity.class));
                return true;
            } else if (itemId == R.id.nav_device) {
                startActivity(new Intent(this, DeviceActivity.class));
                return true;
            } else if (itemId == R.id.nav_settings) {
                startActivity(new Intent(this, ProfileActivity.class));
                return true;
            }
            return false;
        });

        startDashboardPulseAnim();

        setListener();
        initHandler();
    }

    @Override
    protected ActivityBleDeviceBinding getViewBinding(LayoutInflater inflater) {
        return ActivityBleDeviceBinding.inflate(inflater);
    }

    @Override
    protected void onResume() {
        super.onResume();
        com.yc.nadalsdkdemo.utils.SessionManager sm = new com.yc.nadalsdkdemo.utils.SessionManager(this);
        String name = sm.getName();
        if (!android.text.TextUtils.isEmpty(name)) {
            binding.tvGreeting.setText("Привет, " + name);
            binding.ivAvatar.setText(String.valueOf(name.charAt(0)).toUpperCase());
        }

        com.yc.nadalsdkdemo.telemetry.WatchTelemetry telemetry =
                com.yc.nadalsdkdemo.telemetry.TelemetryHub.INSTANCE.getTelemetryFlow().getValue();
        updateAvatarDashUI(telemetry);

        if (MyApplication.isFakeDeviceMode()) {
            updateTelemetryUI(telemetry);
            com.yc.nadalsdkdemo.services.BleSyncService.start(this);
        }
    }

    private void updateAvatarDashUI(com.yc.nadalsdkdemo.telemetry.WatchTelemetry telemetry) {
        if (telemetry == null) return;
        com.yc.nadalsdkdemo.avatar.AvatarProfile profile =
                com.yc.nadalsdkdemo.avatar.AvatarManager.INSTANCE.getProfile(this, telemetry);
        if (binding.dashBioAvatarView != null) {
            binding.dashBioAvatarView.setState(profile.getState());
        }
        if (binding.tvDashAvatarRank != null) {
            binding.tvDashAvatarRank.setText(profile.getRankTitle().toUpperCase() + " · УР. " + profile.getLevel());
        }
        if (binding.tvDashAvatarStateBadge != null) {
            binding.tvDashAvatarStateBadge.setText(profile.getState().getBadgeText());
            try {
                binding.tvDashAvatarStateBadge.setTextColor(android.graphics.Color.parseColor(profile.getState().getBadgeColorHex()));
            } catch (Exception ignored) {}
        }
        if (binding.tvDashAvatarSub != null) {
            String sub = profile.getState().getTitle() + " · " + (profile.getState() == com.yc.nadalsdkdemo.avatar.AvatarState.CHARGED ? "Бонус +50% XP" : "Режим отдыха");
            binding.tvDashAvatarSub.setText(sub);
        }
        if (binding.pbDashAvatarXp != null) {
            binding.pbDashAvatarXp.setMax(profile.getMaxXp());
            binding.pbDashAvatarXp.setProgress(profile.getCurrentXp());
        }
    }

    private void updateTelemetryUI(com.yc.nadalsdkdemo.telemetry.WatchTelemetry telemetry) {
        if (telemetry == null) return;
        updateAvatarDashUI(telemetry);
        com.yc.nadalsdkdemo.intelligence.ReadinessResult readiness =
                com.yc.nadalsdkdemo.intelligence.ReadinessEngine.INSTANCE.calculate(telemetry);
        com.yc.nadalsdkdemo.intelligence.CoachAdvice advice =
                com.yc.nadalsdkdemo.intelligence.SmartDailyCoach.INSTANCE.generate(telemetry);

        if (binding.readinessRingView != null) {
            binding.readinessRingView.setScore(readiness.getScore(), true);
        }
        binding.tvReadinessScore.setText(String.valueOf(readiness.getScore()));
        binding.tvHrvValue.setText(telemetry.getHrvMs() + " мс");

        if (binding.tvCoachTargetStrain != null) {
            binding.tvCoachTargetStrain.setText(advice.getTargetStrain());
            try {
                binding.tvCoachTargetStrain.setTextColor(android.graphics.Color.parseColor(advice.getBadgeColorHex()));
            } catch (Exception ignored) {}
        }
        if (binding.tvCoachRecommendation != null) {
            binding.tvCoachRecommendation.setText(advice.getRecommendation());
        }

        if (binding.livePulseWave != null) {
            binding.livePulseWave.setBpm(telemetry.getHeartRate());
            binding.tvHeartSubtext.setText("Покой " + telemetry.getRestingHeartRate() + " · " + binding.livePulseWave.getZoneTitle());
        }
        binding.tvHeartValue.setText(String.valueOf(telemetry.getHeartRate()));

        binding.tvDetails.setText(telemetry.getDeviceName() + " (CR-A1-084B21)");
        binding.tvConnectState.setText("На связи (BLE 5.3)");
        binding.tvBattery.setText(telemetry.getBatteryPercent() + "% 🔋");
        binding.tvStepsPercent.setText(((int) ((telemetry.getSteps() / (float) telemetry.getStepGoal()) * 100)) + "%");
        binding.tvStepsValue.setText(String.format(java.util.Locale.US, "%,d", telemetry.getSteps()).replace(',', ' '));
        binding.tvCaloriesPercent.setText(((int) ((telemetry.getCalories() / (float) telemetry.getCalorieGoal()) * 100)) + "%");
        binding.tvCaloriesValue.setText(String.valueOf(telemetry.getCalories()));
        binding.tvSleepValue.setText(String.valueOf(telemetry.getSleepScore()));
        binding.tvStressValue.setText(String.valueOf(telemetry.getStressScore()));
        binding.tvSpo2Value.setText(telemetry.getSpo2Percent() + "%");
        binding.tvTempValue.setText(telemetry.getSkinTempC() + "°C");

        com.yc.nadalsdkdemo.widget.CircaGlanceWidget.updateAll(this);
    }
    @Override
    public void onButtonClick(int resId) {
        LogUtils.e("点击了:" + getString(resId));
        if (MyApplication.isFakeDeviceMode()) {
            boolean isNavigationButton = (resId == R.string.bt_connect || resId == R.string.bt_disconnect
                    || resId == R.string.bt_app_remind || resId == R.string.fitness || resId == R.string.workout
                    || resId == R.string.heartRate || resId == R.string.blood_sugar || resId == R.string.weather
                    || resId == R.string.WatchFaceMarket || resId == R.string.Menstrual || resId == R.string.bt_Offline_Map
                    || resId == R.string.bt_ai_train || resId == R.string.bt_universal_file_transfer || resId == R.string.bt_temperature_module
                    || resId == R.string.bt_transaction_reminder || resId == R.string.bt_morning_news || resId == R.string.smart_glasses_audio_device
                    || resId == R.string.bt_clip_custom || resId == R.string.ai_recorder_meeting_recording || resId == R.string.chatGptTittle
                    || resId == R.string.drinkWaterRemind || resId == R.string.contacts_and_sos);
            if (!isNavigationButton) {
                String fakeMsg = FakeWatchManager.getInstance().handleFakeCommand(resId, getString(resId));
                ToastUtil.showToast(fakeMsg);
                LogUtils.i(fakeMsg);
                return;
            }
        }
        switch (resId) {
            case R.string.bt_share_log:
                if (LogUtils.getPrintEnable()) {
                    LogShareUtils.getInstance().shareLog(BleDeviceActivity.this);
                }
                return;
            case R.string.bt_connect:
                connectDevice(deviceAddress);
                return;
            case R.string.bt_disconnect:
                disconnectDevice();
                return;
            case R.string.bt_device_name:
                updateTextView(binding.tvDetails, mUteBleClient.getDeviceName());
                return;
            case R.string.bt_device_address:
                updateTextView(binding.tvDetails, mUteBleClient.getDeviceAddress());
                return;
            case R.string.bt_app_remind:
                startActivity(new Intent(this, AppRemindActivity.class));
                return;
            case R.string.fitness:
                startActivity(new Intent(this, FitnessActivity.class));
                return;
            case R.string.workout:
                startActivity(new Intent(this, WorkOutActivity.class));
                return;
            case R.string.heartRate:
                startActivity(new Intent(this, HeartRateActivity.class));
                return;
            case R.string.blood_sugar:
                if (!DeviceModeJX.isHasFunction_4(DeviceModeJX.IS_SUPPORT_BLOOD_SUGAR)) {
                    showToastNoSupport();
                    return;
                }
                startActivity(new Intent(this, BloodSugarActivity.class));
                return;
            case R.string.weather:
                startActivity(new Intent(this, WeatherActivity.class));
                return;
            case R.string.WatchFaceMarket:
                startActivity(new Intent(this, WatchFaceMarketActivity.class));
                return;
            case R.string.Menstrual:
                startActivity(new Intent(this, MenstrualActivity.class));
                return;
            case R.string.bt_Offline_Map:
                if (!DeviceModeJX.isHasFunction_3(DeviceModeJX.IS_SUPPORT_OFFLINE_MAP)) {
                    showToastNoSupport();
                    return;
                }
                startActivity(new Intent(this, OfflineMapActivity.class));
                return;
            case R.string.bt_ai_train:
                if (!DeviceModeJX.isHasFunction_3(DeviceModeJX.IS_SUPPORT_AI_TRAINING_COURSE)) {
                    showToastNoSupport();
                    return;
                }
                startActivity(new Intent(this, AITrainActivity.class));
                return;
            case R.string.bt_universal_file_transfer:
                if (!DeviceModeJX.isHasFunction_4(DeviceModeJX.IS_SUPPORT_COMMON_FILE_TRANSFER)) {
                    showToastNoSupport();
                    return;
                }
                startActivity(new Intent(this, FileTransferActivity.class));
                return;
            case R.string.bt_temperature_module:
                if (!DeviceModeJX.isHasFunction_4(DeviceModeJX.IS_SUPPORT_BODY_TEMPERATURE)) {
                    showToastNoSupport();
                    return;
                }
                startActivity(new Intent(this, TemperatureModuleActivity.class));
                return;
            case R.string.bt_transaction_reminder:
                if (!DeviceModeJX.isHasFunction_4(DeviceModeJX.IS_SUPPORT_TRANSACTION)) {
                    showToastNoSupport();
                    return;
                }
                startActivity(new Intent(this, TransactionReminderActivity.class));
                return;
            case R.string.bt_morning_news:
                if (!DeviceModeJX.isHasFunction_4(DeviceModeJX.IS_SUPPORT_MORNING_NEWS)) {
                    showToastNoSupport();
                    return;
                }
                startActivity(new Intent(this, MorningNewsActivity.class));
                return;
            case R.string.smart_glasses_audio_device:

                if (!AIGlassesMode.isHasFunction_7(AIGlassesMode.IS_PLATFORM_JLATS3028_GLASSES)) {
                    showToastNoSupport();
                    return;
                }
                startActivity(new Intent(this, SmartGlassesActivity.class));
                return;
            case R.string.bt_clip_custom:
                startActivity(new Intent(this, ClipCustomActivity.class));
                return;
            case R.string.ai_recorder_meeting_recording:

                if (!DeviceModeJX.isHasFunction_4(DeviceModeJX.IS_SUPPORT_AI_RECORDER_MEETING_RECORDING)) {
                    showToastNoSupport();
                    return;
                }
                final Intent intent = new Intent(this, AIRecorderActivity.class);
                intent.putExtra(BleDeviceActivity.DEVICE_NAME, deviceName);
                startActivity(intent);
                return;
        }
        if (!mUteBleClient.isConnected()) {
            ToastUtil.showToast("Please connect the device first");
            return;
        }
        childHandler.sendEmptyMessage(resId);
    }
    @Override
    protected void onViewClick(View v) {

    }

    private Handler childHandler;

    private void initHandler() {
        HandlerThread handlerThread = new HandlerThread("HandlerThread");
        handlerThread.start();
        childHandler = new Handler(handlerThread.getLooper()) {
            @Override
            public void handleMessage(@NonNull Message msg) {
                callInterface(msg.what);
            }
        };
    }

    /**
     * 这里是子线程
     * @param resId
     */
    public void callInterface(int resId) {
        Response<?> response;
        switch (resId) {
            case R.string.querySupportService:
                List<Integer> serviceIdList = getAllListServiceId();
                response = mUteBleConnection.querySupportService(serviceIdList);
                LogUtils.e("querySupportService  response = " + new Gson().toJson(response));
                break;
            case R.string.querySupportCommand:
                response = mUteBleConnection.querySupportCommand(getBaseCommandId());
                LogUtils.e("querySupportCommand  response = " + new Gson().toJson(response));
                break;
            case R.string.setTimeDisplay:
                TimeDisplay timeDisplay = new TimeDisplay();
                timeDisplay.setDateFormat(TimeDisplay.DATE_YYYY_MM_DD);
                timeDisplay.setTimeFormat(TimeDisplay.TIME_HOUR_24);
                response = mUteBleConnection.setTimeDisplay(timeDisplay);
                LogUtils.e("setTimeDisplay  response = " + new Gson().toJson(response));
                break;
            case R.string.setTimeClock:
                int timeSeconds = (int) (System.currentTimeMillis() / 1000);
                int timeZone = 8;
                int minuteOffset = 0;
                TimeClock timeClock1 = new TimeClock();
                timeClock1.setTimeSeconds(timeSeconds);
                timeClock1.setTimeZone(timeZone);
                timeClock1.setMinuteOffset(minuteOffset);
                response = mUteBleConnection.setTimeClock(timeClock1);
                LogUtils.e("setTimeClock  response = " + new Gson().toJson(response));

                break;
            case R.string.getTimeClock:
                response = mUteBleConnection.getTimeClock();
                LogUtils.e("getTimeClock  response = " + new Gson().toJson(response));

                break;
            case R.string.getDeviceInfo:
                DeviceInfoRequest info = new DeviceInfoRequest();
                info.setAddress(true);
                info.setDeviceBtModel(true);
                info.setDeviceVersionType(true);
                response = mUteBleConnection.getDeviceInfo(info);
                LogUtils.e("getDeviceInfo  response = " + new Gson().toJson(response));
                break;
            case R.string.getBatteryInfo:
                response = mUteBleConnection.getBatteryInfo();
                LogUtils.e("getBatteryInfo  response = " + new Gson().toJson(response));

                break;
            case R.string.setScreenAutoLight:
                boolean enable = true;
                response = mUteBleConnection.setScreenAutoLight(enable);
                LogUtils.e("setScreenAutoLight  response = " + new Gson().toJson(response));
                break;
            case R.string.resetFactory:
//                1恢复出厂关机，0恢复出厂重启；
                int type = 0;
                response = mUteBleConnection.resetFactory(type);
                LogUtils.e("resetFactory  response = " + new Gson().toJson(response));
                break;
            case R.string.setCameraStatus:
                int cameraStatus = CameraStatusConfig.STATUS_OPEN;
                response = mUteBleConnection.setCameraStatus(cameraStatus);
                LogUtils.e("resetFactory  response = " + new Gson().toJson(response));
                break;
            case R.string.getFindWearState:
                response = mUteBleConnection.getFindWearState();
                LogUtils.e("getFindWearState  response = " + new Gson().toJson(response));
                break;
            case R.string.setFindWearCmd:
//                0:关闭 1:开启
                response = mUteBleConnection.setFindWearCmd(1);
                LogUtils.e("setFindWearCmd  response = " + new Gson().toJson(response));
                break;
            case R.string.setFindMyPhone:
//               1:要求服务端报警 2:要求服务端停止报警
                response = mUteBleConnection.setFindMyPhone(2);
                LogUtils.e("setFindWearCmd  response = " + new Gson().toJson(response));
                break;
            case R.string.setDisconnectRemind:
                response = mUteBleConnection.setDisconnectRemind(false);
                LogUtils.e("resetFactory  response = " + new Gson().toJson(response));
                break;
            case R.string.setLanguage:
//                0: 公制；1：英制
                response = mUteBleConnection.setLanguage(LanguageType.BAND_LANGUAGE_CN, LanguageType.UNIT_METRIC);
                LogUtils.e("setLanguage  response = " + new Gson().toJson(response));
                break;
            case R.string.getLengthUnits:
//                0: 公制；1：英制
                response = mUteBleConnection.getLengthUnits();
                LogUtils.e("getLengthUnits  response = " + new Gson().toJson(response));
                break;
            case R.string.getDefaultConfiguration:
                response = mUteBleConnection.getDefaultConfiguration();
                LogUtils.e("getDefaultConfiguration  response = " + new Gson().toJson(response));
                break;
            case R.string.querySupportAbilitySet:
                response = mUteBleConnection.querySupportAbilitySet();
                LogUtils.e("querySupportAbilitySet response =" + new Gson().toJson(response));
                break;
            case R.string.sendPermissionResultList:
                List<Integer> permissionResultList1 = new ArrayList<>();
                permissionResultList1.add(1);
                permissionResultList1.add(1);
                AppPermissionSet AppPermissionSet = new AppPermissionSet();
                AppPermissionSet.setPermissionResultList(permissionResultList1);
                response = mUteBleConnection.sendPermissionResultList(AppPermissionSet);

                LogUtils.e("sendPermissionResultList response =" + new Gson().toJson(response));
                break;
            case R.string.getScreenAutoLightState:
                response = mUteBleConnection.getScreenAutoLightState();
                LogUtils.e("getScreenAutoLightState response =" + new Gson().toJson(response));
                break;
            case R.string.notifyIncomingCall: {
                String contact = "来电联系人姓名";
                String number = "18588888888";
                response = mUteBleConnection.notifyIncomingCall(contact, number);
                LogUtils.e("notifyIncomingCall response =" + new Gson().toJson(response));
            }

            break;
            case R.string.notifyOutgoingCall: {
                String contact = "去电联系人姓名";
                String number = "18588888888";
                response = mUteBleConnection.notifyOutgoingCall(contact, number);
                LogUtils.e("notifyOutgoingCall response =" + new Gson().toJson(response));
            }

            break;
            case R.string.notifyHangup:
                response = mUteBleConnection.notifyHangup();
                LogUtils.e("notifyHangup response =" + new Gson().toJson(response));
                break;
            case R.string.notifyAnswerCall:
                response = mUteBleConnection.notifyAnswerCall();
                LogUtils.e("notifyAnswerCall response =" + new Gson().toJson(response));
                break;
            case R.string.notifyMissedCall: {
                String contact = "未接联系人姓名";
                String number = "18588888888";
                response = mUteBleConnection.notifyMissedCall(contact, number);
                LogUtils.e("notifyMissedCall response =" + new Gson().toJson(response));
            }
            break;
            case R.string.setMusicAppPlayInfo:
                MusicAppPlayInfo musicAppPlayInfo = new MusicAppPlayInfo();
                musicAppPlayInfo.setSingerName("张杰");
                musicAppPlayInfo.setSongName("最美的太阳");
                musicAppPlayInfo.setPlayState(MusicAppPlayInfo.APP_PLAYING);
                musicAppPlayInfo.setMaxVolume(15);
                musicAppPlayInfo.setCurrentVolume(8);
                response = mUteBleConnection.setMusicAppPlayInfo(musicAppPlayInfo);
                LogUtils.e("setMusicAppPlayInfo response =" + new Gson().toJson(response));
                break;
            case R.string.setMusicAppStatus:
//                MusicAppStatus.STATUS_SUCCESS = 100000;
//                MusicAppStatus.STATUS_PERMISSION_DENIED = 136001;
//                MusicAppStatus.STATUS_NO_MUSIC_PLAYING = 136002;
                response = mUteBleConnection.setMusicAppStatus(MusicAppStatus.STATUS_SUCCESS);
                LogUtils.e("setMusicAppStatus response =" + new Gson().toJson(response));
                break;
            case R.string.setResponseMusicControl:
//                MusicAppStatus.STATUS_SUCCESS = 100000;
//                MusicAppStatus.STATUS_PERMISSION_DENIED = 136001;
//                MusicAppStatus.STATUS_NO_MUSIC_PLAYING = 136002;
                response = mUteBleConnection.setResponseMusicControl();
                LogUtils.e("setResponseMusicControl response =" + new Gson().toJson(response));
                break;
            case R.string.queryDeviceSupAlarmCountParam:
                if (!DeviceModeJX.isHasFunction_3(DeviceModeJX.IS_SUPPORT_ALARM_FUNCTION_MORE)) {
                    showToastNoSupport();
                    return;
                }
                response = mUteBleConnection.queryDeviceSupAlarmCountParam();
                AlarmCountParamBean alarmCountParamBean = (AlarmCountParamBean) response.getData();
                mFunctionBit = alarmCountParamBean.getFunctionBit();
                mAlarmCount = alarmCountParamBean.getCount();
                LogUtils.e("queryDeviceSupAlarmCountParam response =" + new Gson().toJson(response));
                break;
            case R.string.setAlarmList:
                List<Alarm> listAlarm = new ArrayList<>();
                //支持获取手表支持的闹钟个数和支持的属性设置
                if (DeviceModeJX.isHasFunction_3(DeviceModeJX.IS_SUPPORT_ALARM_FUNCTION_MORE)) {
                    for (int i = 1; i <= mAlarmCount; i++) {
                        Alarm alarm = new Alarm();
                        alarm.setIndex(i);
                        List<Integer> cycleList = List.of(WeekCycle.MONDAY, WeekCycle.TUESDAY, WeekCycle.WEDNESDAY, WeekCycle.THURSDAY, WeekCycle.FRIDAY, WeekCycle.SATURDAY, WeekCycle.SUNDAY);//(周一到周日）
                        alarm.setCycleList(cycleList);
                        alarm.setHour(3 + i);
                        alarm.setMinute(1 + i);
                        alarm.setEnable(true);
                        alarm.setName("我的闹钟" + i);
                        if (mFunctionBit.contains(AlarmCountParamBean.ALARM_SOUND_MODE)) {
                            alarm.setSoundMode(AlarmSoundMode.ALARM_ONLY_VIBRATE);//AlarmSoundMode.ALARM_RING_AND_VIBRATE,AlarmSoundMode.ALARM_ONLY_RING,AlarmSoundMode.ALARM_ONLY_VIBRATE
                        }
                        listAlarm.add(alarm);
                    }
                } else {
                    for (int i = 1; i <= 5; i++) {
                        Alarm alarm = new Alarm();
                        alarm.setIndex(i);
                        List<Integer> cycleList = List.of(WeekCycle.MONDAY, WeekCycle.TUESDAY, WeekCycle.WEDNESDAY, WeekCycle.THURSDAY, WeekCycle.FRIDAY, WeekCycle.SATURDAY, WeekCycle.SUNDAY);//(周一到周日）
                        alarm.setCycleList(cycleList);
                        alarm.setHour(3 + i);
                        alarm.setMinute(1 + i);
                        alarm.setEnable(true);
                        alarm.setName("我的闹钟" + i);
                        listAlarm.add(alarm);
                    }
                }
                response = mUteBleConnection.setAlarmList(listAlarm);
                LogUtils.e("setAlarmList response =" + new Gson().toJson(response));
                break;
            case R.string.getAlarmList:
                response = mUteBleConnection.getAlarmList();
                LogUtils.e("getAlarmList response =" + new Gson().toJson(response));
                break;
            case R.string.setHonorAccount:
                HonorAccountConfig accountConfig = new HonorAccountConfig();
                accountConfig.setCurrentHuid("45d10ff8648f5d9b80fd89808155c1a2ia");
                response = mUteBleConnection.setHonorAccount(accountConfig);
                LogUtils.e("setHonorAccount response =" + new Gson().toJson(response));
                break;
            case R.string.requestDevicePairing:
                response = mUteBleConnection.requestDevicePairing(1);
                LogUtils.e("requestDevicePairing response =" + new Gson().toJson(response));
                break;
            case R.string.queryDeviceBt3State:
                response = mUteBleConnection.queryDeviceBt3State();
                LogUtils.e("queryDeviceBt3State response =" + new Gson().toJson(response));
                break;

            case R.string.getPackageHeader:

                String path = MyApplication.getContext().getExternalCacheDir() + "/nadalsdk/data/otaFile";
                File folder = new File(path);
                if (!folder.exists()) {
                    folder.mkdirs();
                }
                File otaFile = new File(path, "ota_firmware.bin");//固件所在的路径
                PackageHeader packageHeader = new PackageHeader();
                try {
                    packageHeader = mUteBleConnection.getPackageHeader(otaFile);
                } catch (Exception e) {
                    e.printStackTrace();
                }

                LogUtils.e("getPackageHeader response =" + new Gson().toJson(packageHeader));
                break;
            case R.string.prepareUpgrade:
                UpgradeConfig upgradeConfig = new UpgradeConfig();
                upgradeConfig.setVersion("1.1.2");
//                upgradeConfig.setVersion("AT338V000008");
                response = mUteBleConnection.prepareUpgrade(upgradeConfig);
                LogUtils.e("prepareUpgrade response =" + new Gson().toJson(response));
                break;
            case R.string.cancelUpgrade:
                response = mUteBleConnection.cancelUpgrade();
                LogUtils.e("cancelUpgrade response =" + new Gson().toJson(response));
                break;
            case R.string.notifyNewVersion:
                VersionConfig versionConfig = new VersionConfig();
                long size = 123;
                String versionNumber = "1.3.2";
                boolean isDetected = true;
                int checkTime = (int) (System.currentTimeMillis() / 1000);

                versionConfig.setSize(size);
                versionConfig.setVersionNumber(versionNumber);
                versionConfig.setDetected(isDetected);
                versionConfig.setCheckTime(checkTime);
                response = mUteBleConnection.notifyNewVersion(versionConfig);
                LogUtils.e("notifyNewVersion response =" + new Gson().toJson(response));
                break;
            case R.string.setDownloadConfirmResponse:
                DownloadConfig downloadConfig =new DownloadConfig();
                downloadConfig.setNetworkConfirm(false);
                downloadConfig.setAppUpgradeStatus(2);
                response = mUteBleConnection.setDownloadConfirmResponse(downloadConfig);
                LogUtils.e("setDownloadConfirmResponse response =" + new Gson().toJson(response));
                break;
            case R.string.activateElectronicCard:
                int timeSeconds2 = (int) (System.currentTimeMillis() / 1000);
                int timeZone2 = 8;
                int minuteOffset2 = 0;
                TimeClock timeClock2 = new TimeClock();
                timeClock2.setTimeSeconds(timeSeconds2);
                timeClock2.setTimeZone(timeZone2);
                timeClock2.setMinuteOffset(minuteOffset2);
                response = mUteBleConnection.activateElectronicCard(timeClock2);
                //26.4 电子保卡激活请求-回送
//                response = mUteBleConnection.setElectronicCardStatus(ElectronicCardStatus.RECEIVE_STATUS_SUCCESS);
                LogUtils.e("activateElectronicCard response =" + new Gson().toJson(response));
                break;
            case R.string.downloadRuntimeBetaLogFile:
//                String mRootPath = MyApplication.getContext().getExternalCacheDir() + "/nadalsdk/data/beta";
                String mRootPath = LogUtils.getRootPath() +  "/beta";
                File outFile = new File(mRootPath);
                if (!outFile.exists()) {
                    outFile.mkdirs();
                }
                final String[] lastFileName = {""};
                FileService.MultiCallback mMultiCallback = new FileService.MultiCallback() {
                    @Override
                    public void onFound(String[] fileNames) {
                        LogUtils.e("MultiCallback onFound  fileNames =" + new Gson().toJson(fileNames));
                        for (int i = 0; i < fileNames.length; i++) {
                            String fileName = fileNames[i];
                            lastFileName[0] = fileName;
                        }

                    }

                    @Override
                    public File onStart(String fileName) {
                        LogUtils.e("MultiCallback onStart  fileName =" + fileName);
                        File file = new File(outFile, fileName);
                        LogUtils.e("MultiCallback onStart  file =" + file);
                        return file;
                    }

                    @Override
                    public void onProgress(String fileName, int progress, int total) {
                        LogUtils.e("MultiCallback onProgress  fileName =" + fileName + ",progress =" + progress + ",total =" + total);
                    }

                    @Override
                    public void onCompleted(String fileName) {
                        LogUtils.e("MultiCallback onCompleted  fileName =" + fileName);
                    }

                    @Override
                    public void onFail(int code, Throwable throwable) {
                        LogUtils.e("MultiCallback onFail  code =" + code + ",throwable =" + throwable);
                    }
                };
                Future<?> future = mUteBleConnection.downloadRuntimeBetaLogFile(mMultiCallback);
                LogUtils.e("downloadRuntimeBetaLogFile result=" + new Gson().toJson(future));
                break;
            case R.string.getDeviceStandaloneLogInfo:
                response = mUteBleConnection.getDeviceStandaloneLogInfo();
                LogUtils.e("getDeviceStandaloneLogInfo response =" + new Gson().toJson(response));
                break;
            case R.string.deleteDeviceStandaloneLog:
                response = mUteBleConnection.deleteDeviceStandaloneLog();
                LogUtils.e("deleteDeviceStandaloneLog response =" + new Gson().toJson(response));
                break;
            case R.string.openNotify:
                mUteBleClient.openOrCloseNotify(true);
                break;
            case R.string.closeNotify:
                mUteBleClient.openOrCloseNotify(false);
                break;
            case R.string.bt_acts_ota:
                startActivity(new Intent(this, ActsOtaActivity.class));
                break;
            case R.string.setWorldClock:
                if (!DeviceModeJX.isHasFunction_2(DeviceModeJX.IS_SUPPORT_WORLD_CLOCK)) {
                    showToastNoSupport();
                    return;
                }
                List<WorldClockInfo> worldClockInfos = new ArrayList<>();
                for (int i = 0; i < 5; i++) {
                    WorldClockInfo worldClockInfo = new WorldClockInfo();
                    worldClockInfo.setCityName("北京" + i);
                    worldClockInfo.setTimeZone(7.25f + i);
                    worldClockInfos.add(worldClockInfo);
                }
                response = mUteBleConnection.setWorldClock(worldClockInfos);
                LogUtils.e("setWorldClock response =" + new Gson().toJson(response));
                break;
            case R.string.queryWorldClock:
                if (!DeviceModeJX.isHasFunction_2(DeviceModeJX.IS_SUPPORT_WORLD_CLOCK)) {
                    showToastNoSupport();
                    return;
                }
                response = mUteBleConnection.queryWorldClock();
                List<WorldClockInfo> worldClockInfos3 = (List<WorldClockInfo>) response.getData();
                LogUtils.e("queryWorldClock response =" + new Gson().toJson(response));
                break;
            case R.string.querySupportWorldClockCount:
                if (!DeviceModeJX.isHasFunction_2(DeviceModeJX.IS_SUPPORT_WORLD_CLOCK)) {
                    showToastNoSupport();
                    return;
                }
                response = mUteBleConnection.querySupportWorldClockCount();
                LogUtils.e("querySupportWorldClockCount response =" + new Gson().toJson(response));
                break;
            case R.string.deleteAllWorldClock:
                if (!DeviceModeJX.isHasFunction_2(DeviceModeJX.IS_SUPPORT_WORLD_CLOCK)) {
                    showToastNoSupport();
                    return;
                }
                List<WorldClockInfo> worldClockInfos2 = new ArrayList<>();
                response = mUteBleConnection.setWorldClock(worldClockInfos2);
                LogUtils.e("deleteAllWorldClock response =" + new Gson().toJson(response));
                break;
            case R.string.queryScreenOnDurationList:
                response = mUteBleConnection.queryScreenOnDurationList();
                LogUtils.e("queryScreenOnDurationList response =" + new Gson().toJson(response));
                break;
            case R.string.bt_jl_ota:
                startActivity(new Intent(this, JLOtaActivity.class));
                break;
            case R.string.chatGptTittle:
                if (DeviceModeJX.isHasFunction_2(DeviceModeJX.IS_SUPPORT_CHAT_GPT)
                        || DeviceModeJX.isHasFunction_4(DeviceModeJX.IS_SUPPORT_YOUJIE_AUTHORIZATION)) {
                    startActivity(new Intent(this, ChatGptActivity.class));
                } else {
                    showToastNoSupport();
                }

                break;
            case R.string.queryTwoWaySetting:
                if (!DeviceModeJX.isHasFunction_2(DeviceModeJX.IS_SUPPORT_TWO_WAY_SETTINGS)) {
                    showToastNoSupport();
                    return;
                }
                response = mUteBleConnection.queryTwoWaySetting();
                LogUtils.e("queryTwoWaySetting response =" + new Gson().toJson(response));
                //使用示例：
                if (response.getErrorCode() == ErrorCode.CODE_OK) {
                    TwoWaySettingConfig twoWaySettingConfig = (TwoWaySettingConfig) response.getData();
                    //设备端是否显示 心率定时测量时间间隔,true为显示
                    boolean isDeviceDisplay = TwoWayDisplayJX.isDisplay(twoWaySettingConfig.getTwoWayHeartIntervalFlag(), TwoWayDisplayJX.DEVICE_DISPLAY);
                    //APP端是否显示 心率定时测量时间间隔,true为显示
                    boolean isAppDisplay = TwoWayDisplayJX.isDisplay(twoWaySettingConfig.getTwoWayHeartIntervalFlag(), TwoWayDisplayJX.APP_DISPLAY);
                }

                break;

            case R.string.drinkWaterRemind:
                if (!DeviceModeJX.isHasFunction_3(DeviceModeJX.IS_SUPPORT_DRINK_WATER_REMIND)) {
                    showToastNoSupport();
                    return;
                }
                startActivity(new Intent(this, DrinkWaterActivity.class));
                break;
            case R.string.contacts_and_sos:
                startActivity(new Intent(this, ContactsSosSmsActivity.class));
                break;
            case R.string.setDeviceWarrantyTime:
                if (!DeviceModeJX.isHasFunction_3(DeviceModeJX.IS_SUPPORT_SN_QUALITY_WARRANTY)) {
                    showToastNoSupport();
                    return;
                }
                int activationTime = (int) (System.currentTimeMillis() / 1000);
                ActivateWarrantyTimeConfig activateWarrantyTimeConfig = new ActivateWarrantyTimeConfig();
                activateWarrantyTimeConfig.setActivationTime(activationTime);
                activateWarrantyTimeConfig.setWarrantyTime(activationTime + (365 * 24 * 60 * 60));
                response = mUteBleConnection.setDeviceWarrantyTime(activateWarrantyTimeConfig);
                LogUtils.e("setDeviceWarrantyTime response =" + new Gson().toJson(response));
                break;
            case R.string.queryDeviceActivateWarrantyTime:
//                if (!DeviceModeJX.isHasFunction_3(DeviceModeJX.IS_SUPPORT_SN_QUALITY_WARRANTY)) {
//                    showToastNoSupport();
//                    return;
//                }
                response = mUteBleConnection.queryDeviceActivateWarrantyTime();
                LogUtils.e("queryDeviceWarrantyTime response =" + new Gson().toJson(response));
                break;
            case R.string.setDeviceSN:
                String sn = "uteglyc1234567890";
                response = mUteBleConnection.setDeviceSN(sn);
                LogUtils.e("setDeviceSN response =" + new Gson().toJson(response));
                break;
            case R.string.setDeviceMac:
                String mac = "78:02:B7:13:6C:6E";
                response = mUteBleConnection.setDeviceMac(mac);
                LogUtils.e("setDeviceMac response =" + new Gson().toJson(response));
                break;
            case R.string.setDeviceBluetoothName:
                String bluetoothName = "mybluetooth01";
                response = mUteBleConnection.setDeviceBluetoothName(bluetoothName);
                LogUtils.e("setDeviceBluetoothName response =" + new Gson().toJson(response));
                break;
            case R.string.setDevicePassword:
                String devicePassword = "123789";//必须是6位密码，0-9纯数字
                DevicePasswordConfig devicePasswordConfig = new DevicePasswordConfig();
                devicePasswordConfig.setEnable(true);
                devicePasswordConfig.setPassword(devicePassword);
                response = mUteBleConnection.setDevicePassword(devicePasswordConfig);
                LogUtils.e("setDevicePassword response =" + new Gson().toJson(response));
                break;
            case R.string.queryDevicePassword:
                response = mUteBleConnection.queryDevicePassword();
                LogUtils.e("queryDevicePassword response =" + new Gson().toJson(response));
                break;
            case R.string.setScreenInfoConfig:
                ScreenInfoConfig screenInfoConfig = new ScreenInfoConfig();
                screenInfoConfig.setBrightness(0x19);
                screenInfoConfig.setAutoBrightnessEnable(SwitchState.SWITCH_YES);
                screenInfoConfig.setTouchScreenEnable(SwitchState.SWITCH_NO);
                screenInfoConfig.setCoverOffScreenEnable(SwitchState.SWITCH_NO);
                response = mUteBleConnection.setScreenInfoConfig(screenInfoConfig);
                LogUtils.e("setScreenInfoConfig response =" + new Gson().toJson(response));
                break;
            case R.string.queryScreenInfoConfig:
                response = mUteBleConnection.queryScreenInfoConfig();
                LogUtils.e("queryScreenInfoConfig response =" + new Gson().toJson(response));
                break;
            case R.string.setSoundVibrationConfig:
                SoundVibrationConfig soundVibrationConfig = new SoundVibrationConfig();
                soundVibrationConfig.setMediaAudioEnable(SwitchState.SWITCH_YES);
                soundVibrationConfig.setMuteModeEnable(SwitchState.SWITCH_YES);
                soundVibrationConfig.setVolume(10);
                response = mUteBleConnection.setSoundVibrationConfig(soundVibrationConfig);
                LogUtils.e("setSoundVibrationConfig response =" + new Gson().toJson(response));
                break;
            case R.string.querySoundVibrationConfig:
                response = mUteBleConnection.querySoundVibrationConfig();
                LogUtils.e("querySoundVibrationConfig response =" + new Gson().toJson(response));
                break;
            case R.string.setDeviceDebugState: {
                DeviceDebugState deviceDebugState = new DeviceDebugState();
//                设备调试模式状态。0:未进入调试模式，1：进入调试模式
                deviceDebugState.setDebugState(DeviceDebugState.DEBUG_MODE_YES);
                response = mUteBleConnection.setDeviceDebugState(deviceDebugState);
                LogUtils.e("setDeviceDebugState response =" + new Gson().toJson(response));
            }
            break;
            case R.string.setDeviceActivationStateDisplay: {
                DeviceActiveInfo deviceActiveInfo = new DeviceActiveInfo();
                deviceActiveInfo.setActiveState(DeviceActiveInfo.ACTIVATE_SUCCESS);
                response = mUteBleConnection.setDeviceActivationStateDisplay(deviceActiveInfo);
                LogUtils.e("setDeviceActivationStateDisplay response =" + new Gson().toJson(response));
            }
            break;
            case R.string.setVoiceAssistantEnable:
                if (!DeviceModeJX.isHasFunction_3(DeviceModeJX.IS_SUPPORT_WAKE_VOICE_ASSISTANT)) {
                    showToastNoSupport();
                    return;
                }
                response = mUteBleConnection.setVoiceAssistantEnable(false);
                LogUtils.e("setVoiceAssistantEnable response =" + new Gson().toJson(response));
            break;
            case R.string.setAppRingStatusToDevice:
                boolean isRinging = false;//是否响铃中
                response = mUteBleConnection.setAppRingStatusToDevice(isRinging);
                LogUtils.e("setAppRingStatusToDevice response =" + new Gson().toJson(response));
            break;

            case R.string.queryElectronicCard:
                if (!DeviceModeJX.isHasFunction_4(DeviceModeJX.IS_SUPPORT_ELECTRONIC_CARD)) {
                    showToastNoSupport();
                    return;
                }
                response = mUteBleConnection.queryElectronicCard();
                LogUtils.e("queryElectronicCard response =" + new Gson().toJson(response));
            break;
            case R.string.syncElectronicCard:
                if (!DeviceModeJX.isHasFunction_4(DeviceModeJX.IS_SUPPORT_ELECTRONIC_CARD)) {
                    showToastNoSupport();
                    return;
                }

                List<ElectronicCardInfo> electronicCardInfoList = new ArrayList<>();
                ElectronicCardInfo cardInfo = new ElectronicCardInfo();
                cardInfo.setName("name1两种方法都会创建一个包含前120字节的新数组。Arrays.copyOfRange()方法内部也是调用System.arraycopy()，但语法更简洁注意第二个参数是结束索引（不包含），所以写120表");
//                cardInfo.setName("name1两种方法都会创建一个包含前120字节的新数组");
                cardInfo.setContent("Content1两种方法都会创建一个包含前120字节的新数组。Arrays.copyOfRange()方法内部也是调用System.arraycopy()，但语法更简洁8。注意第二个参数是结束索引（不包含），所以写120表");
//                cardInfo.setContent("Content1两种方法都会创建一个包含前120字节的新数组");
                electronicCardInfoList.add(cardInfo);
                cardInfo = new ElectronicCardInfo();
                cardInfo.setName("name2两种方法都会创建一个包含前120字节的新数组。Arrays.copyOfRange()方法内部也是调用System.arraycopy()，但语法更简洁注意第二个参数是结束索引（不包含），所以写120表");
//                cardInfo.setName("name2两种方法都会创建一个包含前120字节的新数组");
                cardInfo.setContent("Content2两种方法都会创建一个包含前120字节的新数组。Arrays.copyOfRange()方法内部也是调用System.arraycopy()，但语法更简洁。注意第二个参数是结束索引（不包含），所以写120表");
//                cardInfo.setContent("Content2两种方法都会创建一个包含前120字节的新数组");
                electronicCardInfoList.add(cardInfo);
                response = mUteBleConnection.syncElectronicCard(electronicCardInfoList);
                LogUtils.e("syncElectronicCard response =" + new Gson().toJson(response));
                break;

            case R.string.setRegionLockConfig:
                if (!DeviceModeJX.isHasFunction_4(DeviceModeJX.IS_SUPPORT_REGIONAL_LOCK)) {
                    showToastNoSupport();
                    return;
                }
                response = mUteBleConnection.setRegionLockConfig(new RegionLockConfig(RegionLockConfig.INSIDE_REGION));
                LogUtils.e("setRegionLockConfig response =" + new Gson().toJson(response));
                break;
            case R.string.clearAccountID:
                response = mUteBleConnection.clearAccountID();
                LogUtils.e("clearAccountID response =" + new Gson().toJson(response));
                break;
            case R.string.queryHealthLabFunStatus:
                if (!DeviceModeJX.isHasFunction_5(DeviceModeJX.IS_SUPPORT_HEALTH_LAB)) {
                    showToastNoSupport();
                    return;
                }
                response = mUteBleConnection.queryHealthLabFunStatus();
                LogUtils.e("queryHealthLabFunStatus response =" + new Gson().toJson(response));
                break;
            case R.string.setHealthLabFunStatus:
                if (!DeviceModeJX.isHasFunction_5(DeviceModeJX.IS_SUPPORT_HEALTH_LAB)) {
                    showToastNoSupport();
                    return;
                }

                List<HealthLabFunStatusInfo> healthLabFunStatusInfos = new ArrayList<>(
                        List.of(new HealthLabFunStatusInfo(HealthLabFunStatusInfo.FUN_BLOOD_PRESSURE, 1),
                        new HealthLabFunStatusInfo(HealthLabFunStatusInfo.FUN_BLOOD_SUGAR, 1)));
                response = mUteBleConnection.setHealthLabFunStatus(healthLabFunStatusInfos);
                LogUtils.e("setHealthLabFunStatus response =" + new Gson().toJson(response));
                break;
            case R.string.setFrequentLocations:
                if (!DeviceModeJX.isHasFunction_5(DeviceModeJX.IS_SUPPORT_AMAP_NAVI)) {
                    showToastNoSupport();
                    return;
                }
                List<String> locations = new ArrayList<>();
                locations.add("故宫");
                locations.add("长城");
                locations.add("鸟巢");
                locations.add("圆明园");
                locations.add("五棵松体育馆");
                Response<?> response1 = mUteBleConnection.setFrequentLocations(locations);
                LogUtils.i("setFrequentLocations response1 =" + new Gson().toJson(response1));
                break;
            case R.string.syncSearchResult:
                if (!DeviceModeJX.isHasFunction_5(DeviceModeJX.IS_SUPPORT_AMAP_NAVI)) {
                    showToastNoSupport();
                    return;
                }
                List<NaviSearchResultInfo> list = new ArrayList<>();
                for (int i = 0; i < 5; i++) {
                    NaviSearchResultInfo info1 = new NaviSearchResultInfo();
                    info1.setId(i);
                    info1.setTitle("我是标题");
                    info1.setAddress("我是地址");
                    info1.setDistance(1000);
                    info1.setPOITypeText("我是POI");
                    info1.setBusinessStartHours(8);
                    info1.setBusinessStartMinute(22);
                    info1.setBusinessEndHours(18);
                    info1.setBusinessEndMinute(33);
                    info1.setRating(43);//具体评分*10 比如4.3分，则发送43.*10=43
                    info1.setRatingNumber(100);
                    info1.setExtendedData("扩展数据 详细地址、公交车、地铁线路等");
                    list.add(info1);
                }
                mUteBleConnection.syncSearchResult(list, new OlmNaviSyncListener() {
                    @Override
                    public void onNaviSyncState(int state) {
                        LogUtils.e("onNaviSyncState state =" + state);
                    }

                    @Override
                    public void onNaviSyncProgress(int progress) {
                        LogUtils.e("onNaviSyncProgress progress =" + progress);
                    }
                });
                break;
            case R.string.setNaviData:
                if (!DeviceModeJX.isHasFunction_5(DeviceModeJX.IS_SUPPORT_AMAP_NAVI)) {
                    showToastNoSupport();
                    return;
                }
                String testData = "08041A5A080210021A0CE697A0E5908DE98193E8B7AF220CE697A0E5908DE98193E8B7AF28AF2730AA224099014881015801681072230891802018F8CBC7FFFEFFFFFFFF01221209C89F12D07F0000001174CA5ADB0DA1170C78058A0100205A2A05312E302E30";
                byte[] data = GBUtils.getInstance().hexStringToBytes(testData);
                Response<?> response2 = mUteBleConnection.setNaviData(data);
                LogUtils.i("setNaviData response =" + new Gson().toJson(response2));
                break;
            case R.string.setNaviPointDistanceAndTime:
                if (!DeviceModeJX.isHasFunction_5(DeviceModeJX.IS_SUPPORT_AMAP_NAVI)) {
                    showToastNoSupport();
                    return;
                }
                Response<?> response3 = mUteBleConnection.setNaviPointDistanceAndTime(1000,30);
                LogUtils.i("setNaviPointDistanceAndTime response =" + new Gson().toJson(response3));
                break;
            default:
                break;

        }
    }

    private final Handler pulseAnimHandler = new Handler(Looper.getMainLooper());
    private final Runnable pulseAnimRunnable = new Runnable() {
        @Override
        public void run() {
            if (!isFinishing()) {
                animateDashboardPulse();
                pulseAnimHandler.postDelayed(this, 1200);
            }
        }
    };

    private void startDashboardPulseAnim() {
        pulseAnimHandler.post(pulseAnimRunnable);
    }

    private void animateDashboardPulse() {
        java.util.Random rnd = new java.util.Random();
        int h1 = 10 + rnd.nextInt(14);
        int h2 = 18 + rnd.nextInt(16);
        int h3 = 14 + rnd.nextInt(14);
        int h4 = 20 + rnd.nextInt(14);
        int h5 = 12 + rnd.nextInt(12);

        int density = (int) getResources().getDisplayMetrics().density;
        binding.bar1.getLayoutParams().height = h1 * density;
        binding.bar2.getLayoutParams().height = h2 * density;
        binding.bar3.getLayoutParams().height = h3 * density;
        binding.bar4.getLayoutParams().height = h4 * density;
        binding.bar5.getLayoutParams().height = h5 * density;
        binding.llPulseBars.requestLayout();

        int hr = 70 + rnd.nextInt(5);
        binding.tvHeartValue.setText(String.valueOf(hr));
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
        LogUtils.i("BleDeviceActivity onDestroy");
        pulseAnimHandler.removeCallbacksAndMessages(null);
        disconnectDevice();
        if (LogUtils.getPrintEnable()) {
            LogShareUtils.getInstance().deleteLogFilesSevenDayAgo();
        }
    }

    private void connectDevice(String address) {
        if (isAndroid_12()) {
            String[] permissions = new String[]{Manifest.permission.BLUETOOTH_CONNECT};
            new RxPermissions(this).request(permissions).subscribe(new Action1<Boolean>() {
                @Override
                public void call(Boolean aBoolean) {
                    if (aBoolean) {
                        connectDevice2(address);
                    } else {
                        ToastUtil.showToast("Please allow APP to access BLUETOOTH_CONNECT permission");
                    }
                }
            });
        } else {
            connectDevice2(address);
        }
    }

    private void connectDevice2(String address) {
        if ("00:11:22:33:44:55".equals(address) || MyApplication.isFakeDeviceMode()) {
            MyApplication.setFakeDeviceMode(true);
            if (mBleConnectStateListener != null) {
                mBleConnectStateListener.onConnecteStateChange(BleConnectStateListener.STATE_CONNECTED);
            }
            FakeWatchManager.getInstance().startFakeDataStream(this);
            return;
        }
        if (!mUteBleClient.isConnectedGatt()) {//need BLUETOOTH_CONNECT permission
            mProgressDialog.show();
            mProgressDialog.setMessage(StringUtil.getInstance().getStringResources(R.string.bt_state_connecting));
            mUteBleConnection = mUteBleClient.connect(address);//need BLUETOOTH_CONNECT permission
        } else {
            ToastUtil.showToast("Connected, no need to connect again");
        }
    }

    private void disconnectDevice() {
        if (MyApplication.isFakeDeviceMode()) {
            FakeWatchManager.getInstance().stopFakeDataStream();
            MyApplication.setFakeDeviceMode(false);
            if (mBleConnectStateListener != null) {
                mBleConnectStateListener.onConnecteStateChange(BleConnectStateListener.STATE_DISCONNECTED);
            }
            ToastUtil.showToast("Disconnected demo watch");
            return;
        }
        if (mUteBleClient.isConnectedGatt()) {//need BLUETOOTH_CONNECT permission
            mUteBleClient.disconnect();//need BLUETOOTH_CONNECT permission
        } else {
            ToastUtil.showToast("Disconnected, no need to disconnect again");
        }
    }


    private void updateConnectState(final int state) {
        if (state < 0) {
            return;
        }
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                String text = StringUtil.getInstance().getStringResources(state);
                binding.tvConnectState.setText(text);
                if (state == R.string.bt_state_connected) {
                    binding.tvConnectState.setBackgroundTintList(ColorStateList.valueOf(ContextCompat.getColor(BleDeviceActivity.this, R.color.status_connected_bg)));
                    binding.tvConnectState.setTextColor(ContextCompat.getColor(BleDeviceActivity.this, R.color.status_connected_text));
                } else {
                    binding.tvConnectState.setBackgroundTintList(ColorStateList.valueOf(ContextCompat.getColor(BleDeviceActivity.this, R.color.status_disconnected_bg)));
                    binding.tvConnectState.setTextColor(ContextCompat.getColor(BleDeviceActivity.this, R.color.status_disconnected_text));
                }
            }
        });
    }

    void updateTextView(final TextView view, final String text) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                view.setText(text);
            }
        });
    }


    private boolean isAndroid_12() {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.S;
    }

    BleConnectStateListener mBleConnectStateListener = new BleConnectStateListener() {
        @Override
        public void onConnecteStateChange(int status) {
            int state = -1;
            switch (status) {
                case BleConnectStateListener.STATE_DISCONNECTED:
                    LogUtils.i("disconnected");
                    state = R.string.bt_state_disconnected;
                    mProgressDialog.dismiss();
                    com.yc.nadalsdkdemo.services.BleSyncService.stop(BleDeviceActivity.this);
                    Flowable.timer(1, TimeUnit.SECONDS).observeOn(AndroidSchedulers.mainThread()).subscribe(s -> {
                        reConnectDeviceForJlOta();//延迟1秒钟后再重连，因为杰理OTA时，先收到了断开蓝牙连接的回调后才收到OTA成功的回调
                    });
                    break;
                case BleConnectStateListener.STATE_CONNECTING:
                    LogUtils.i("connecting");
                    state = R.string.bt_state_connecting;
                    break;
                case BleConnectStateListener.STATE_CONNECTED:
                    LogUtils.i("connected," + mUteBleClient.getDeviceName() + "," + mUteBleClient.getDeviceAddress());
                    state = R.string.bt_state_connected;
                    mProgressDialog.dismiss();
                    com.yc.nadalsdkdemo.utils.HapticHelper.heavyClick(BleDeviceActivity.this);
                    com.yc.nadalsdkdemo.services.BleSyncService.start(BleDeviceActivity.this);
                    if (SPDao.getInstance().getJLOtaSecondStage()){
                        if (!JLOtaUtil.isJLOtaInit) {//如果当前APP还处于OTA升级界面，不需要跳转
                            LogUtils.i("已连接上的设备属于杰理平台OTA第二阶段，需要马上进入OTA");
                            Intent intent = new Intent(BleDeviceActivity.this, JLOtaActivity.class);
                            intent.putExtra(JLOtaActivity.DIRECT_UPGRADE_KEY, true);
                            startActivity(intent);
                        }


                    }
                    break;
                case BleConnectStateListener.STATE_SET_REGION_LOCK:
                    LogUtils.i("APP下发指定区域指令");
                    state = R.string.setRegionLockConfig;
                    Response<?> response = mUteBleConnection.setRegionLockConfig(new RegionLockConfig(RegionLockConfig.INSIDE_REGION));
                    LogUtils.e("setRegionLockConfig response =" + new Gson().toJson(response));
                    break;
            }
            updateConnectState(state);
        }
    };
    DeviceNotifyListener mDeviceNotifyListener = new DeviceNotifyListener() {
        @Override
        public void onNotify(@NonNull UteBleDevice device, @NonNull Notify notify) {
            LogUtils.i("onNotify notify = " + new Gson().toJson(notify));
            int eventType = notify.getType();
            switch (eventType) {
                case NotifyType.DEVICE_PAIRED_STATE_NOTIFY:
                    DevicePairedState devicePairedState = (DevicePairedState) notify.getData();
                    if (devicePairedState.getPairedState() == 1) {
                        HonorAccountConfig accountConfig = new HonorAccountConfig();
                        //用户唯一ID
                        String userId ="be2ed6e6ae8c6c280f9eed43db0f102bod";//pro
//                        String userId ="40086000132970007";
//                        String userId ="e19d340fb9a9b09babd2c9a2c33ae203od";
                        accountConfig.setCurrentHuid(userId);
                        mUteBleConnection.setHonorAccount(accountConfig);
                    } else {
                        disconnectDevice();
                    }
                    break;
                case NotifyType.DEVICE_RESET_NOTIFY:
                    DeviceResetNotify deviceResetNotify =  (DeviceResetNotify) notify.getData();
                    LogUtils.i("deviceResetNotify, getResetResult = " + deviceResetNotify.getResetResult());
                    if (deviceResetNotify.getResetResult()) {
                        //设备端点击了重启，可等几秒钟后调用重连
//                        connectDevice(deviceAddress);
                    } else {
                        disconnectDevice();
                    }
                    break;
                case NotifyType.JL_OTA_SECOND_MODE:
                    JLOtaSecondModeNotify jlOtaSecondModeNotify = (JLOtaSecondModeNotify) notify.getData();
                    SPDao.getInstance().setJLOtaSecondStage(jlOtaSecondModeNotify.getSuccess());
                    break;
            }
        }
    };

    private List<Integer> getAllListServiceId() {
        List<Integer> baseList = new ArrayList<>();
        baseList.add(ServiceIds.ACCOUNT);
        baseList.add(ServiceIds.ALARM);
//        baseList.add(ServiceIds.APPLICATION);
        baseList.add(ServiceIds.CALL);
//        baseList.add(ServiceIds.COMMON_FILE);
        baseList.add(ServiceIds.CONTACT_PERSON);
        baseList.add(ServiceIds.DEVICE_MANAGE);
//        baseList.add(ServiceIds.ECG);

//        baseList.add(ServiceIds.EPHEMERIS);
//        baseList.add(ServiceIds.ESIM);
//        baseList.add(ServiceIds.FILE_MANAGER);
//        baseList.add(ServiceIds.FILE_UPLOAD);
        baseList.add(ServiceIds.FITNESS);
//        baseList.add(ServiceIds.FONT);
        baseList.add(ServiceIds.HEART_RATE);
        baseList.add(ServiceIds.HONOR_ACCOUNT);

//        baseList.add(ServiceIds.HTTP_PROXY);
        baseList.add(ServiceIds.LOCATION);
        baseList.add(ServiceIds.LOST);
        baseList.add(ServiceIds.MAINTENANCE);
        baseList.add(ServiceIds.MENSTRUAL);
//        baseList.add(ServiceIds.MID_WARE);
        baseList.add(ServiceIds.MUSIC);
        baseList.add(ServiceIds.NOTIFICATION);

        baseList.add(ServiceIds.OTA);
        baseList.add(ServiceIds.P2P);
//        baseList.add(ServiceIds.PHD_KIT);
        baseList.add(ServiceIds.SLEEP_APNEA);
//        baseList.add(ServiceIds.SOCKET_NETWORK);
        baseList.add(ServiceIds.STRESS);
//        baseList.add(ServiceIds.SYNERGY);
//        baseList.add(ServiceIds.THIRD_PARTY_APPLICATION_SERVICE);

//        baseList.add(ServiceIds.VOICE_ASSISTANT);
        baseList.add(ServiceIds.WATCH_FACE);
        baseList.add(ServiceIds.WEAR_ENGINE_MESSAGE);
        baseList.add(ServiceIds.WEATHER);
//        baseList.add(ServiceIds.WEB_SOCKET_PROXY);
        baseList.add(ServiceIds.WORKOUT);
        return baseList;
    }

    private SupportCommandRequest getBaseCommandId() {

        List<Integer> ALARMCommandID = List.of(1, 2, 3);
        List<Integer> CALLCommandID = List.of(1, 2);
        List<Integer> CONTACT_PERSONCommandID = List.of(1001, 1003, 1004, 1005);
        List<Integer> DEVICE_MANAGECommandID = List.of(4, 7, 8, 9, 10, 13, 14, 16, 41, 42);
        List<Integer> FITNESSCommandID = List.of(1, 3, 5, 7, 8, 9);
        List<Integer> FONTCommandID = List.of(1);
        List<Integer> HEART_RATECommandID = List.of(1, 3, 5, 9, 23, 28, 29, 30, 33, 34, 35, 1000);
        List<Integer> HONOR_ACCOUNTCommandID = List.of(3, 4);
        List<Integer> LOSTCommandID = List.of(1, 3);
        List<Integer> MAINTENANCECommandID = List.of(11);
        List<Integer> MENSTRUALCommandID = List.of(1, 4);
        List<Integer> MUSICCommandID = List.of(1, 2, 3);
        List<Integer> NOTIFICATIONCommandID = List.of(1, 4, 5, 6, 7, 8);
        List<Integer> OTACommandID = List.of(1, 1000, 1001);
        List<Integer> WATCH_FACECommandID = List.of(1, 2, 3, 4, 5, 8, 9, 1000, 1002);
        List<Integer> WEATHERCommandID = List.of(4, 5, 7, 8, 9, 10, 12);
        List<Integer> WORKOUTCommandID = List.of(1, 2, 3, 7, 8, 9, 10, 11, 17, 18);

        List<SupportCommandRequest.CommandSet> list = new ArrayList<>();
        list.add(new SupportCommandRequest.CommandSet(ServiceIds.DEVICE_MANAGE, DEVICE_MANAGECommandID));
        list.add(new SupportCommandRequest.CommandSet(ServiceIds.NOTIFICATION, NOTIFICATIONCommandID));
        list.add(new SupportCommandRequest.CommandSet(ServiceIds.FITNESS, FITNESSCommandID));
        list.add(new SupportCommandRequest.CommandSet(ServiceIds.ALARM, ALARMCommandID));
        SupportCommandRequest supportCommandRequest = new SupportCommandRequest();
        supportCommandRequest.setCommandSetList(list);
        return supportCommandRequest;
    }
    private void reConnectDeviceForJlOta() {
        if (SPDao.getInstance().getJLOtaSecondStage()) {
            String addressOta = deviceAddressUp1(deviceAddress);
            LogUtils.i("杰理OTA 中，地址+1  重连");
            mUteBleClient.setSupportUserIdPair(false);
            UteBleClient.getUteBleClient().connect(addressOta);
        }
    }
    /**
     * 地址+1
     * @param devAddr
     * @return
     */
    private String deviceAddressUp1(String devAddr) {
        byte[] data = BluetoothUtil.addressCovertToByteArray(devAddr);
        int value = CHexConver.byteToInt(data[data.length - 1]) + 1;
        data[data.length - 1] = CHexConver.intToByte(value);
        String newAddr = BluetoothUtil.hexDataCovetToAddress(data);
        LogUtils.i("deviceAddressUp1 devAddr = "+devAddr+",newAddr = "+newAddr);
        return newAddr;
    }
}