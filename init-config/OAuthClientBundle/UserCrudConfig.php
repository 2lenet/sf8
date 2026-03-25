<?php

declare(strict_types=1);

namespace App\Crudit\Config;

use App\Crudit\Datasource\UserDatasource;
use Lle\CruditBundle\Contracts\CrudConfigInterface;
use Lle\CruditBundle\Crud\AbstractCrudConfig;
use Lle\CruditBundle\Dto\Field\Field;

class UserCrudConfig extends AbstractCrudConfig
{
    public function __construct(
        UserDatasource $datasource,
    ) {
        $this->datasource = $datasource;
    }

    /**
     * @return array<Field|Field[]>
     */
    public function getFields(string $key): array
    {
        $username = Field::new('username');
        $email = Field::new('email');
        $prenom = Field::new('prenom');
        $nom = Field::new('nom');
        $actif = Field::new('actif');
        $profil = Field::new('profil');
        $impersonate = Field::new('id')
            ->setLabel('field.impersonate')
            ->setTemplate('crudit/user/_impersonate.html.twig');

        return match ($key) {
            CrudConfigInterface::INDEX, CrudConfigInterface::SHOW => [
                $username,
                $email,
                $prenom,
                $nom,
                $actif,
                $profil,
                $impersonate,
            ],
            default => [],
        };
    }

    public function getRootRoute(): string
    {
        return 'app_crudit_user';
    }
}
