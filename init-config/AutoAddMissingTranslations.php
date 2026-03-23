<?php

namespace App\EventListener;

use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Component\DependencyInjection\ParameterBag\ParameterBagInterface;
use Symfony\Component\EventDispatcher\Attribute\AsEventListener;
use Symfony\Component\HttpKernel\Event\TerminateEvent;
use Symfony\Component\Translation\DataCollectorTranslator;
use Symfony\Component\Translation\Provider\Dsn;
use Symfony\Contracts\HttpClient\HttpClientInterface;

#[AsEventListener]
final class AutoAddMissingTranslations
{
    private ?DataCollectorTranslator $dataCollector;

    private const string HOST = 'localise.biz';

    public function __construct(
        protected string $locoDsn,
        protected HttpClientInterface $client,
        protected ParameterBagInterface $parameterBag,
        #[Autowire(service: 'translator.data_collector')] ?DataCollectorTranslator $translator = null,
    ) {
        $this->dataCollector = $translator;
    }

    public function __invoke(TerminateEvent $event): void
    {
        if (!$this->support()) {
            return;
        }

        if (null === $this->dataCollector) {
            return;
        }

        $dsn = new Dsn($this->locoDsn);
        $endpoint = 'default' === $dsn->getHost() ? self::HOST : $dsn->getHost();
        $endpoint .= $dsn->getPort() ? ':' . $dsn->getPort() : '';

        $this->client = $this->client->withOptions([
            'base_uri' => 'https://' . $endpoint . '/api/',
            'headers' => [
                'Authorization' => 'Loco ' . $dsn->getUser(),
            ],
        ]);

        $missingMessages = [];
        $messages = $this->dataCollector->getCollectedMessages();
        foreach ($messages as $message) {
            if (DataCollectorTranslator::MESSAGE_MISSING === $message['state']) {
                $locale = $message['locale'];
                $domain = $message['domain'];
                if (!array_key_exists($locale, $missingMessages)) {
                    $missingMessages[$locale] = [];
                }
                if (!array_key_exists($domain, $missingMessages[$locale])) {
                    $missingMessages[$locale][$domain] = [];
                }
                $missingMessages[$locale][$domain][] = $message['id'];
            }
        }
        foreach ($missingMessages as $loc => $mess) {
            foreach ($mess as $domain => $idlist) {
                foreach ($idlist as $id) {
                    $this->createAssets($id, (string)$domain);
                }
            }
        }
    }

    private function createAssets(string $id, string $domain): int
    {
        $response = $this->client->request('POST', 'assets', [
            'body' => [
                'id' => $id, // must be globally unique, not only per domain
                'text' => $id,
                'type' => 'text',
                'default' => 'untranslated',
            ],
        ]);
        $status = $response->getStatusCode();
        if ($status == 201) {
            $createdId = $response->toArray(false)['id'];
            $response = $this->client->request('POST', sprintf('assets/%s/tags', rawurlencode($createdId)), [
                'body' => ['name' => $domain],
            ]);
        }

        return $status;
    }

    public function support(): bool
    {
        if ($this->parameterBag->get('kernel.environment') === 'dev') {
            return true;
        }

        return false;
    }
}
