# Registering a Device

Devices are Astarte's main entities for exchanging data. Even though a Device usually represents the physical Device communicating with Astarte, they might as well be mapped to other entities, such as individual sensors or aggregated gateways. A Device always belongs to a Realm and is identified by a [Device ID](010-design_principles.html#device-id), which has to be unique at least within its Realm.

Devices communicate with Astarte through Transports - in most installations, this means through an MQTT Broker (VerneMQ with Astarte's plugin). Before this happens, though, Devices must obtain credentials for accessing their Transport and, most of all, make themselves known to Astarte. This happens through the Registration process.

In Astarte, Registering a device means obtaining an unique *Credentials Secret* (Registration Credentials), univocally associated to a Device ID, through a well-known workflow and pipeline. If you are not familiar with these concepts, please refer to [Pairing Architecture](050-pairing_mechanism.html) to learn more about Pairing's workflow basics.

The *Credentials Secret* can then be used by the Device for accessing Pairing API and getting information and Credentials for its Transport. As such, registration happens **only once** during a Device's lifecycle, and is a security-sensitive process. As such, this process is usually carried over (in production scenarios) through an *Agent*.

## Registration Agent

An *Agent*'s purpose is to perform Registration on behalf of a Device. *Agents* should be the only components in your infrastructure with enough credentials to access [Pairing's Agent APIs](api/index.html?urls.primaryName=Pairing%20API#/agent) (as a rule of thumb, it is a bad idea to give access to Pairing API to anything which isn't an Agent).

When setting up an Astarte project, it is fundamental to define beforehand how your Devices will be registered and hence where your Agent(s) will belong. There's two main ways for implementing an Agent, even though in production scenarios *On Board Agents* are **strongly discouraged** as they expose a single point of failure in terms of a Realm's whole fleet security.

### On Board Agent

*Please keep in mind that On Board Agents are not advised in production, as a single compromised device/token might compromise the Registration routine for your entire fleet. They should be used only in non-critical use cases or during testing and development.*

On Board Agents are provided as a feature by Astarte's SDK, and hide the detail of Device registration by integrating an Agent into the SDK itself. This allows to deliver the same credentials to each device belonging to a Realm.
Of course, this also opens up a single point of failure in the whole fleet's security, as Credentials aren't tied to a specific device - as such, if compromised, they might allow an attacker to register an arbitrary device into a Realm, unless other policies prevent him from doing so.

To create a On Board Agent, you simply need to emit a long-enough lived token from your Realm's private key with access to [Pairing's Agent APIs](api/index.html?urls.primaryName=Pairing%20API#/agent). This token should then be delivered to your devices and provided to the SDK in order to carry over the Registration. The SDK will do this automatically and without any need for additional code, as long as you set the `agentKey` configuration key to a meaningful value, and no *Credentials Secret* has been set.

### 3rd Party Agent

A more secure approach to the Registration process is having a 3rd Party agent. In such a case, an external component is in charge of requesting a *Credentials Secret* to Pairing and delivering it to the target Device.

This approach has a number of benefits: in terms of Security, the Agent uses a short-lived token and can follow the Realm's authentication workflow just like any other application. For what concerns daily operations, the Agent can implement any arbitrary logic to make a decision on whether a Device should be registered or not.

In such cases, Devices have an out-of-band communication mechanism with the Agent in which the Credentials are exchanged. Usually, these cases fall under two main categories:

#### "Local" or "Plant" Agents

In this scenario, devices are imprinted with their *Credentials Secret* in the production plant. The Device might not even be connected to the Internet, whereas the machine running the Agent has access to the target Astarte Cluster and adequate Credentials for Registration.

Once the Agent acquires the Device ID of the Device which should be registered, it issues the request to Astarte's Pairing API and obtains the Device's *Credentials Secret*. At this stage, the Agent is in charge of delivering the *Credentials Secret* to the Device the way it sees fit. As a best practice, the *Credentials Secret* should then be saved to an OTP area or a dedicated secure storage in the device to prevent tampering or accidental loss.

Even though this is arguably the most secure mechanism available for Registering a Device, it might not fit every use case as the Device will be irrevocabily assigned to a specific Astarte Cluster and a specific Realm in that Cluster before it even connects.

#### "Remote" Agents

If your use case demands more flexibility, Registering a Device in a plant might not fit your Device's lifecycle. This could be likely if, for example, Realm or Cluster assignment should be done dynamically once the Device reaches its final user.

In this case, this role is usually delegated to an external web application acting as an Agent. In this case, it's up to the user setting up all mechanisms for delivering the *Credentials Secret* to the Device, which includes securing the communication channel. On the other hand, this allows an extremely flexible approach to Registration, which can be implemented through an entirely custom logic.

## Credentials Secret Lifecycle

*Credentials Secrets* are meant to be immutable - as such, they should be handled with extreme care. *Credentials Secrets* are used only for interacting with Pairing, hence to obtain Credentials for a Transport which, on the other hand, are meant to be volatile.

A Device can be Registered an arbitrary number of times before its *Credentials Secret* is used for the first time for interacting with Pairing. This is done to ensure the entire Registration process, including any kind of external custom logic of the Agents, has been carried over successfully, allowing a de-facto "retry" until there's certainty the Device has access to its *Credentials Secret*. Please note that when Registering a Device, a new *Credentials Secret* is generated every time.

Once the *Credentials Secret* is used for retrieving Credentials for a Transport for the first time, Astarte prevents further registration of the same Device again. There's no defined procedure for substituting a *Credentials Secret* - it can be done by performing manual operation, but it should be considered an unusual/emergency procedure (e.g.: a Device has been tampered and got back to its plant with its previous *Credentials Secret* compromised).
