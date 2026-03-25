<?php

declare(strict_types=1);

namespace App\Entity;

use App\Crudit\Datasource\Filterset\UserFilterSet;
use App\Entity\User;
use Doctrine\ORM\EntityManagerInterface;
use Lle\CruditBundle\Brick\BrickResponse\FlashBrickResponse;
use Lle\CruditBundle\Brick\BrickResponseCollector;
use Lle\CruditBundle\Datasource\AbstractDoctrineDatasource;
use Lle\CruditBundle\Filter\FilterState;
use Lle\OAuthClientBundle\Exception\ConnectException;
use Lle\OAuthClientBundle\Service\ConnectApiService;
use Symfony\Contracts\Service\Attribute\Required;

class UserDatasource extends AbstractDoctrineDatasource
{
    public function __construct(
        EntityManagerInterface $entityManager,
        FilterState $filterState,
        protected ConnectApiService $connectApiService,
        protected BrickResponseCollector $brickResponseCollector,
    ) {
        parent::__construct($entityManager, $filterState);
    }

    public function getClassName(): string
    {
        return User::class;
    }

    #[Required]
    public function setFilterset(UserFilterSet $filterSet): void
    {
        $this->filterset = $filterSet;
    }

    public function save(object $resource): bool
    {
        /** @var User $user */
        $user = $resource;
        $data = $this->serialize($user);

        // On met à jour sur le connect
        if ($user->getConnectId() !== null) {
            // Mise à jour
            try {
                $this->connectApiService->edit($data);

                if (!parent::save($resource)) {
                    return false;
                }
            } catch (ConnectException $e) {
                if ($e->getCode() === ConnectException::USER_ALREADY_EXISTS) {
                    $this->brickResponseCollector->add(
                        new FlashBrickResponse(
                            FlashBrickResponse::ERROR,
                            'flash.user.user_already_exists'
                        )
                    );
                } else {
                    $this->brickResponseCollector->add(
                        new FlashBrickResponse(
                            FlashBrickResponse::ERROR,
                            'flash.user.update_error'
                        )
                    );
                }

                return false;
            }
        } else {
            // Création
            try {
                $response = $this->connectApiService->new([
                    'user' => $data,
                    'sendMail' => true,
                ]);
                $user->setConnectId($response['id']);

                if (!parent::save($resource)) {
                    return false;
                }
            } catch (ConnectException $e) {
                if ($e->getCode() === ConnectException::USER_ALREADY_EXISTS) {
                    $this->brickResponseCollector->add(
                        new FlashBrickResponse(
                            FlashBrickResponse::ERROR,
                            'flash.user.user_already_exists'
                        )
                    );
                } else {
                    $this->brickResponseCollector->add(
                        new FlashBrickResponse(
                            FlashBrickResponse::ERROR,
                            'flash.user.create_error'
                        )
                    );
                }

                return false;
            }
        }

        return true;
    }

    public function delete($id): bool
    {
        /** @var class-string $className */
        $className = $this::getClassName();

        /** @var ?User $resource */
        $resource = $this->entityManager->find($className, $id);

        if ($resource) {
            $connectId = $resource->getConnectId();
            if ($connectId) {
                $this->connectApiService->delete($connectId);
            }

            return parent::delete($id);
        }

        return false;
    }

    private function serialize(User $user): array
    {
        $data = [
            'username' => $user->getUsername(),
            'email' => $user->getEmail(),
            'firstname' => $user->getPrenom(),
            'lastname' => $user->getNom(),
            'isActive' => $user->isActif(),
            'roles' => ['ROLE_' . $user->getProfil()?->getName()],
            'id' => $user->getConnectId(),
        ];

        if ($user->getProfil()) {
            $data['profiles'] = [
                [
                    'name' => $user->getProfil()->getName(),
                    'libelle' => $user->getProfil()->getLabel(),
                ],
            ];
        }

        return $data;
    }
}
