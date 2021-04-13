package net.mullvad.mullvadvpn.ui.serviceconnection

import android.os.Looper
import android.os.Messenger
import android.os.RemoteException
import android.util.Log
import net.mullvad.mullvadvpn.dataproxy.AppVersionInfoCache
import net.mullvad.mullvadvpn.dataproxy.RelayListListener
import net.mullvad.mullvadvpn.di.SERVICE_CONNECTION_SCOPE
import net.mullvad.mullvadvpn.ipc.DispatchingHandler
import net.mullvad.mullvadvpn.ipc.Event
import net.mullvad.mullvadvpn.ipc.Request
import net.mullvad.mullvadvpn.service.ServiceInstance
import net.mullvad.mullvadvpn.ui.MainActivity
import org.koin.core.component.KoinApiExtension
import org.koin.core.parameter.parametersOf
import org.koin.core.qualifier.named
import org.koin.core.scope.KoinScopeComponent
import org.koin.core.scope.Scope
import org.koin.core.scope.inject

// Container of classes that communicate with the service through an active connection
//
// The properties of this class can be used to send events to the service, to listen for events from
// the service and to get values received from events.
@OptIn(KoinApiExtension::class)
class ServiceConnection(private val service: ServiceInstance, mainActivity: MainActivity) :
    KoinScopeComponent {
    override val scope: Scope by lazy {
        getKoin().createScope(
            SERVICE_CONNECTION_SCOPE,
            named(SERVICE_CONNECTION_SCOPE), this
        )
    }
    val dispatcher = DispatchingHandler(Looper.getMainLooper()) { message ->
        Event.fromMessage(message)
    }

    val daemon = service.daemon
    val accountCache = AccountCache(service.messenger, dispatcher)
    val connectionProxy = ConnectionProxy(service.messenger, dispatcher)
    val keyStatusListener = KeyStatusListener(service.messenger, dispatcher)
    val locationInfoCache = LocationInfoCache(dispatcher)
    val settingsListener = SettingsListener(dispatcher)
    val splitTunneling by inject<SplitTunneling>(
        parameters = { parametersOf(service.messenger, dispatcher) }
    )
    val vpnPermission = VpnPermission(service.messenger)

    val appVersionInfoCache = AppVersionInfoCache(mainActivity, daemon, settingsListener)
    val customDns = CustomDns(service.messenger, settingsListener)
    var relayListListener = RelayListListener(daemon, settingsListener)

    init {
        appVersionInfoCache.onCreate()
        registerListener()
    }

    fun onDestroy() {
        closeScope()
        dispatcher.onDestroy()

        accountCache.onDestroy()
        connectionProxy.onDestroy()
        keyStatusListener.onDestroy()
        locationInfoCache.onDestroy()
        settingsListener.onDestroy()

        appVersionInfoCache.onDestroy()
        customDns.onDestroy()
        relayListListener.onDestroy()
    }

    private fun registerListener() {
        val listener = Messenger(dispatcher)
        val request = Request.RegisterListener(listener)

        try {
            service.messenger.send(request.message)
        } catch (exception: RemoteException) {
            Log.e("mullvad", "Failed to register listener for service events", exception)
        }
    }
}
