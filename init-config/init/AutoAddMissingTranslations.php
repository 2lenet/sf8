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
    private const API_PATH = '/api/project/translation/';

    private ?DataCollectorTranslator $dataCollector;

    public function __construct(
        protected string $cruditTranslationDsn,
        protected HttpClientInterface $client,
        protected ParameterBagInterface $parameterBag,
        #[Autowire(service: 'translator.data_collector')]
        ?DataCollectorTranslator $translator = null,
    ) {
        $this->dataCollector = $translator;
    }

    public function __invoke(TerminateEvent $event): void
    {
        if (!$this->support() || null === $this->dataCollector) {
            return;
        }

        $entries = [];
        foreach ($this->dataCollector->getCollectedMessages() as $message) {
            if (DataCollectorTranslator::MESSAGE_MISSING === $message['state']) {
                $entries[$message['locale'] . '|' . $message['domain'] . '|' . $message['id']] = [
                    'key' => $message['id'],
                    'locale' => $message['locale'],
                    'domain' => $message['domain'],
                    // No content: crudit-studio must register the key as untranslated, not as
                    // translated to its own id.
                    'content' => null,
                ];
            }
        }

        if ($entries === []) {
            return;
        }

        $this->reportMissingKeys(array_values($entries));
    }

    /**
     * @param list<array{key: string, locale: string, domain: string, content: null}> $entries
     */
    private function reportMissingKeys(array $entries): void
    {
        $dsn = new Dsn($this->cruditTranslationDsn);
        $projectCode = $dsn->getUser();
        $scheme = $dsn->getOption('scheme', 'https');
        $endpoint = $dsn->getHost() . ($dsn->getPort() ? ':' . $dsn->getPort() : '');

        $this->client->request(
            'POST',
            sprintf('%s://%s%spush/%s', $scheme, $endpoint, self::API_PATH, $projectCode),
            [
                'auth_bearer' => $dsn->getPassword(),
                'json' => ['translations' => $entries],
            ]
        );
    }

    public function support(): bool
    {
        if ($this->parameterBag->get('kernel.environment') === 'dev') {
            return true;
        }

        return false;
    }
}
